# FraOS — STACK AI LOCALE (vLLM + Unsloth)

> Come far girare inferenza e fine-tuning su FraOS, e **cosa aspettarsi davvero** da una
> RTX 2080 Ti. Decisione di riferimento: [D-032](DECISIONS.md#d-032).
>
> Regola di fondo: **niente di tutto questo va bakato nell'immagine.** Python, PyTorch e CUDA
> userspace cambiano in continuazione, e metterli in un sistema immutabile significa dover
> ricostruire l'immagine a ogni versione. Vivono in container o in un venv nella home.

## Il vincolo che decide tutto: Turing

La **RTX 2080 Ti** è architettura **Turing, compute capability 7.5**. Non è "vecchia" in senso
generico: è vecchia rispetto a **tre feature precise** che lo stack AI moderno dà per scontate.

| Feature | Richiede | 2080 Ti | Conseguenza pratica |
|---|---|---|---|
| **bfloat16** | Ampere (8.0+) | ❌ | Tutto va forzato a **float16**. Bf16 ha più range dinamico: in fp16 alcuni training divergono e serve loss scaling. **È un limite di silicio, non aggirabile** — vedi sotto |
| **FlashAttention 2** | Ampere (8.0+) | ❌ | vLLM ripiega su altri backend attention: funziona, ma più lento e con più VRAM per il contesto |
| **VRAM** | — | **11 GB** | È questo il tetto vero. Un 7B in fp16 vuole ~14 GB: **non ci sta**. Servono modelli quantizzati |

**Quello che invece c'è:** compute capability 7.5 è **esplicitamente supportata da vLLM**
(verificato nel `CMakeLists.txt` upstream: `CUDA_SUPPORTED_ARCHS` include `7.5` in tutte le
varianti di build). Non è una GPU tagliata fuori, è una GPU con dei paletti.

### bfloat16: perché non si può sbloccare

Domanda legittima: è un blocco software, come il ray tracing che NVIDIA ha "abilitato" sulle
GTX 10xx via driver? **No. È silicio.**

I **Tensor Core** sono unità di calcolo fisiche, e ogni generazione ne supporta un elenco fisso
di formati:

| Generazione | Formati supportati dai Tensor Core |
|---|---|
| **Turing (2ª gen)** — 2080 Ti | FP16, INT8, INT4, INT1 |
| **Ampere (3ª gen)** — 30xx | FP16, **BF16**, **TF32**, INT8, INT4, FP64 |

Su TU102 le unità che moltiplicano matrici in bf16 **non esistono**. Non c'è un flag da alzare:
non c'è il circuito.

**Il paragone col ray tracing regge, ma porta alla conclusione opposta.** Quando NVIDIA ha
abilitato DXR sulle GTX 10xx (2019), non ha "sbloccato" niente: ha fatto girare il ray tracing
sugli shader CUDA generici, in emulazione. Risultato: 3-10× più lento delle schede con RT core
veri. Era una dimostrazione, non una feature usabile.

Con bf16 varrebbe lo stesso: si può *emulare* in software (convertendo avanti e indietro), ma
sarebbe **più lento del fp16 nativo**, che sulla 2080 Ti gira sui Tensor Core veri. Si pagherebbe
per andare più piano.

**Diverso è il caso dei blocchi artificiali**, dove l'hardware c'è e il driver lo inibisce — come
il P2P sulle RTX 4090, riattivato da driver modificati della community. Lì il silicio c'era.
Qui no: nessun vBIOS, nessun firmware, nessuna patch al driver può aggiungere un'unità di calcolo
che non è stata stampata sul chip.

**La buona notizia:** per l'**inferenza** fp16 va benissimo, e la differenza è quasi sempre
irrilevante. Il vantaggio di bf16 (esponente a 8 bit, stesso range dinamico di fp32) conta
soprattutto in **training**, dove i gradienti possono andare in overflow o underflow. Per questo:

- **inferenza (vLLM)** → `--dtype half` e via, nessuna rinuncia pratica
- **fine-tuning (Unsloth/PEFT)** → fp16 **con loss scaling** (`GradScaler`, o `fp16=True` nei
  `TrainingArguments`: lo gestiscono loro). Mai impostare `bf16=True`: fallisce e basta

### Cosa ci gira, realisticamente

| Modello | Formato | VRAM | Esito |
|---|---|---|---|
| 7B / 8B | **AWQ o GPTQ 4-bit** | ~5-6 GB | ✅ comodo, con margine per il contesto |
| 7B / 8B | fp16 | ~14 GB | ❌ non entra |
| 13B / 14B | AWQ 4-bit | ~9-10 GB | ⚠️ entra ma con poco contesto |
| 3B e inferiori | fp16 | ~6 GB | ✅ |
| 30B+ | qualsiasi | — | ❌ fuori portata |

---

## vLLM — inferenza

**Via consigliata: container.** Il NVIDIA Container Toolkit è **già bakato nell'immagine**
([`build.sh`](../build_files/build.sh)), quindi la GPU è visibile ai container senza altro setup.

```bash
podman run -d --name vllm \
  --device nvidia.com/gpu=all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  docker.io/vllm/vllm-openai:latest \
  --model <org/modello-AWQ> \
  --dtype half \
  --quantization awq \
  --gpu-memory-utilization 0.90 \
  --max-model-len 4096
```

**I flag che contano su questa GPU:**

| Flag | Perché |
|---|---|
| `--dtype half` | **obbligatorio**: senza, vLLM prova bfloat16 e si ferma con un errore di capability |
| `--quantization awq` (o `gptq`) | l'unico modo per far stare un 7B negli 11 GB |
| `--max-model-len` | il contesto costa VRAM: su 11 GB va tenuto corto, non lasciato al default del modello |
| `--gpu-memory-utilization` | quanto della VRAM può prendersi. Con il desktop acceso non alzarlo troppo: Niri e il browser ne usano un po' |

Espone un'API compatibile OpenAI su `http://localhost:8000/v1` — quindi qualsiasi client che
parla con l'API OpenAI (incluse le estensioni di VS Code) ci si attacca cambiando solo la base URL.

Per fermarlo: `podman stop vllm`. Per farlo ripartire al boot:
`podman generate systemd --new --name vllm > ~/.config/systemd/user/vllm.service`.

---

## Unsloth — fine-tuning

Unsloth si usa in tre modi: **Desktop** (app), **Studio** (web UI, Beta), **Core** (libreria).

Installer ufficiale per Linux:
```bash
curl -fsSL https://unsloth.ai/install.sh | sh
unsloth studio        # la web UI, di default su 127.0.0.1
```

> ⚠️ **Da verificare sulla macchina vera, prima di farci affidamento.**
> Il README di Unsloth dichiara, per Unsloth Studio: *"Training works on RTX 30/40/50,
> Blackwell, DGX Spark, Station and more"*. **La serie RTX 20 non è elencata.**
> Unsloth Core ha storicamente supportato le GPU dalla capability 7.0 in su (V100, T4, RTX 20),
> ma il supporto dello **Studio** su Turing non è confermato dalla documentazione attuale.
>
> Se lo Studio rifiuta la GPU, i ripieghi in ordine di preferenza sono:
> 1. **Unsloth Core** da script Python (QLoRA 4-bit, `dtype=torch.float16`, mai bf16)
> 2. **PEFT + bitsandbytes** direttamente con HuggingFace: più verboso, ma nessun vincolo di
>    supporto oltre a quelli di Turing
> 3. GPU a noleggio per i training seri (il fine-tuning è l'uso che più soffre gli 11 GB)

**Dove installarlo:** nella home, in un venv. Su un sistema atomico è la via giusta —
`~/.local` e la home sono scrivibili, e PyTorch installato da pip si porta dietro il proprio
runtime CUDA senza toccare l'immagine. **Non usare `rpm-ostree install` per roba Python.**

Se preferisci l'isolamento pieno:
```bash
distrobox create --name ai --image nvidia/cuda:12.6.0-devel-ubuntu24.04 --nvidia
distrobox enter ai
```

---

## ⚠️ Le due regole d'oro

### 1. MAI `rpm-ostree install` per roba Python

```bash
rpm-ostree install python3-torch     # ← NO. Mai.
pip install torch                    # ← nemmeno questo, fuori da un venv
```

**Perché è un errore serio, non uno stilistico:** `rpm-ostree install` crea un *layer* sopra
l'immagine. Quel layer va **ricomposto a ogni aggiornamento del sistema**, quindi:

- ogni `bootc upgrade` diventa più lento e più fragile
- se un pacchetto layered entra in conflitto con la nuova immagine, **l'aggiornamento fallisce**
  e resti indietro senza accorgertene
- lo stack Python cambia ogni poche settimane: staresti ricomponendo il sistema di continuo
- e soprattutto: **non serve**. La home è scrivibile, i venv funzionano perfettamente, e PyTorch
  installato da pip si porta dietro il proprio runtime CUDA

`rpm-ostree install` va usato solo per **provare al volo** un pacchetto di sistema; se convince,
il posto giusto è una riga in `build_files/build.sh`.

### 2. Lo stack AI si aggiorna da sé — ma `torch` no

Il sistema si aggiorna con `bootc upgrade` (immagine ricostruita ogni notte dalla CI). Lo stack
AI, stando fuori dall'immagine, resterebbe indietro in silenzio: per questo c'è
**`fraos-ai-update`**, incluso nell'immagine, con un **timer utente settimanale già abilitato**.

```bash
fraos-ai-update --dry-run                    # cosa farebbe, senza toccare niente
fraos-ai-update                              # aggiorna adesso
systemctl --user status fraos-ai-update.timer
journalctl --user -u fraos-ai-update         # cosa ha fatto l'ultima volta
systemctl --user disable fraos-ai-update.timer   # per spegnerlo
```

**Cosa aggiorna:** solo ciò che esiste già — le immagini container AI che hai già scaricato e i
pacchetti del venv (`unsloth`, `transformers`, `trl`, `peft`, `accelerate`, `datasets`,
`bitsandbytes`, `huggingface_hub`). Se non usi lo stack AI non fa nulla e non scarica nulla.

**`torch` è escluso di proposito.** È il pacchetto più delicato: è legato alla versione di CUDA e
al driver, e aggiornarlo alla cieca è il modo classico per ritrovarsi l'ambiente rotto — su una
GPU Turing ancora di più, perché le build recenti di PyTorch abbandonano progressivamente le
architetture vecchie. Si aggiorna a mano, quando lo decidi tu:

```bash
~/.local/share/fraos-ai/venv/bin/pip install -U torch
```

---

## Cosa è bakato nell'immagine (e cosa no)

| Nell'immagine ✅ | Fuori dall'immagine ❌ |
|---|---|
| `nvidia-container-toolkit` — GPU nei container | vLLM → container |
| driver NVIDIA (dalla base Bazzite) | Unsloth / PyTorch → venv nella home |
| `git-lfs` — i pesi su HuggingFace viaggiano su LFS | modelli → `~/.cache/huggingface` |
| `podman`, `podman-compose`, `distrobox` | CUDA toolkit di sviluppo → distrobox |

Il motivo è sempre lo stesso: **ciò che cambia ogni settimana non va in un sistema immutabile.**
Un aggiornamento di PyTorch non deve costare una ricostruzione dell'immagine e un reboot.

## Verifiche al primo utilizzo

```bash
nvidia-smi                                    # driver e VRAM disponibile
podman run --rm --device nvidia.com/gpu=all \
  docker.io/nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi   # GPU visibile ai container
```
Se il secondo comando fallisce ma il primo funziona, il problema è nel CDI del toolkit, non nel
driver: `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`.
