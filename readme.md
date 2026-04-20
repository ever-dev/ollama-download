# Download Ollama for Linux
Go to https://ollama.com/download/ollama-linux-amd64.tar.zst on Google Chrome, it will download file automatically.

# Download qwen3-coder:30b and qwen2.5-coder:32b
- Open `qwen3-coder-30b.bat` file to download qwen3-coder:30b model.
- Open `qwen2.5-coder-32b.bat` file to download qwen2.5-coder:32b model.

# Final result
- `ollama-linux-amd64.tar.zst` file
- `qwen3-coder_30b.gguf` file
- `qwen2.5-coder_32b.gguf` file

# Test on Windows
- Download Ollama from `https://ollama.com/download`
- Install `OllamaSetup.exe`
- Open `cmd` and run `test-qwen3-coder-30b.bat` and `test-qwen2.5-coder-32b.bat`
- Run `ollama list` and should see `qwen3-coder:30b` and `qwen2.5-coder:32b` listed.