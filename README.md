# Tsunami014's Neovim configuration

## 🛠️ Installation

To use the AI you will need to add a file in `lua/user/secrets.lua` which contains:
```lua
return {
  OPENAI_API_KEY = "sk-xxxxxxx",
  GEMINI_API_KEY = "your-gemini-key",
  DEEPSEEK_API_KEY = "your-deepseek-key",
}
```

### Make a backup of your current nvim and shared folder
```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

### Clone the repository
```shell
git clone https://github.com/Tsunami014/nvimConfig ~/.config/nvim
```
(or to `%userprofile%\AppData\Local\nvim` on Windows)

### Start Neovim
```shell
nvim
```

