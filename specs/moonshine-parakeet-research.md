# Moonshine Small Streaming vs Parakeet TDT 0.6B v3

## Scope

Compare the repository's **Moonshine small-streaming-en**, not the older Moonshine Base/Tiny models, with NVIDIA's **parakeet-tdt-0.6b-v3**. This is source research, not a local benchmark. Sources below are live upstream documentation, which can differ from the repository's pinned runtime.

Local configuration: `modules/services/moonshine-stt/work.nix` runs a local user daemon. `packages/moonshine-stt/default.nix` pins runtime 0.1.1 and quantized `small-streaming-en/quantized_26_07_30` models, using the native Moonshine/ONNX libraries.

## Published accuracy and size

| Metric | Moonshine Small Streaming | Parakeet TDT v3 |
| --- | --- | --- |
| Parameters | 123 million | 600 million |
| English Open ASR average WER | 7.84% | 6.34% |
| LibriSpeech test-clean WER | 2.49% float paper reference; 2.61% shipped quantized model | 1.93% |
| Language coverage of compared model | English | 25 European languages |

Sources: [Moonshine available models](https://github.com/moonshine-ai/moonshine/blob/main/docs/models/available-models.md), [Moonshine accuracy methodology](https://github.com/moonshine-ai/moonshine/blob/main/docs/models/accuracy.md), [NVIDIA model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3).

Lower WER is better. The published Open ASR averages favor Parakeet by **1.50 percentage points**, approximately **19% fewer word errors relative to Moonshine's score**. These are separate upstream evaluations, not a controlled local head-to-head. Moonshine explicitly says its English leaderboard scores use floating-point Transformers models, while the deployed library uses quantized models. Its quantized LibriSpeech score is measured whole-utterance with VAD disabled, not through the live dictation pipeline. Consequently these numbers do not predict exact error rates on the user's microphone, accent, names, or technical vocabulary.

## Speed, latency, and hardware

- **Moonshine targets low-latency local streaming.** Its native library processes speech while the user speaks. That makes it a good architectural fit for the existing dictation daemon. [Official README](https://github.com/moonshine-ai/moonshine)
- **Parakeet targets high-throughput transcription.** NVIDIA describes it as GPU-optimized. The card also documents a native C++/GGUF runtime, so CUDA is not an absolute requirement. The card specifies at least 2 GB RAM to load the model; that is not a complete deployment memory budget. [Model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
- **Parakeet can stream via chunked inference.** NVIDIA's example uses 2-second chunks, 2 seconds of right context, and 10 seconds of left context. That particular setup is not an equivalent low-latency comparison with Moonshine. These settings are an example, not a claim that all Parakeet runtimes have a fixed two-second minimum. [Streaming example in model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3#streaming-with-parakeet-models)
- Parameter count is roughly 4.9 times larger for Parakeet, but **does not imply 4.9 times the latency or RAM**. Architecture, precision, runtime, device, and batching matter. No controlled same-hardware comparison of these exact deployed models was established here. Do not compare GPU batch throughput with CPU interactive finalization latency.

## Recommendation

**Accuracy-first, especially GPU-backed transcription:** benchmark Parakeet; its published English accuracy is better and it adds multilingual support.

**Low-overhead always-on local dictation:** retain Moonshine as the baseline. Its streaming design and existing integration make it the lower-risk choice; an actual CPU speed winner requires measurement.

**Alternative within Moonshine:** Medium Streaming has 245M parameters and a published 6.65% English average WER, closer to Parakeet's 6.34%. It is worth testing before changing engines, but it is not guaranteed to retain Small's latency. [Available models](https://github.com/moonshine-ai/moonshine/blob/main/docs/models/available-models.md)

For a decision, replay the same representative dictation recordings on the intended device and runtime. Measure transcription WER, speech-end-to-final-text p50/p95 latency (including endpointing and network if applicable), time to first partial, CPU/GPU utilization, and peak RAM/VRAM. Keep streaming and whole-file results separate.

No models were downloaded or executed, and no Nix configuration was changed.
