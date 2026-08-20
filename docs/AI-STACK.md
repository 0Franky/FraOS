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
| **bfloat16** | Ampere (8.0+) | ❌ | Tutto va forzato a **float16**. Bf16 ha più range dinamico: in fp16 alcuni training divergono e serve loss scaling |
| **FlashAttention 2** | Ampere (8.0+) | ❌ | vLLM ripiega su altri backend attention: funziona, ma più lento e con più VRAM per il contesto |
| **VRAM** | — | **11 GB** | È questo il tetto vero. Un 7B in fp16 vuole ~14 GB: **non ci sta**. Servono modelli quantizzati |

**Quello che invece c'è:** compute capability 7.5 è **esplicitamente supportata da vLLM**
(verificato nel `CMakeLists.txt` upstream: `CUDA_SUPPORTED_ARCHS` include `7.5` in tutte le
varianti di build). Non è una GPU tagliata fuori, è una GPU con dei paletti.

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
