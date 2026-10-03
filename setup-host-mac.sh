#!/bin/bash
# host tools for macOS, actual dev happens inside the VM (see setup-vm.sh)
set -euxo pipefail

cd $HOME/Code/setup/

if ! command -v brew >/dev/null; then
	echo "installing homebrew.."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

echo "updating..."
brew update && brew upgrade
brew install git curl btop cloc cmake ripgrep

mkdir -p $HOME/.config/
mkdir -p $HOME/Code/

echo "setting up key repeat.."
# holding a key repeats it instead of showing the accent picker (needed for hjkl in vim)
defaults write -g ApplePressAndHoldEnabled -bool false
# repeat interval and initial delay, in units of 15ms (UI minimums are 2 and 15)
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

echo "setting up zsh..."
brew install zsh-autosuggestions
ln -sf $HOME/Code/setup/.zshrc $HOME/.zshrc

echo "installing neovim.."
brew install neovim
ln -sfn $HOME/Code/setup/nvim $HOME/.config

echo "installing tmux.."
brew install tmux fd sk
ln -sf $HOME/Code/setup/.tmux.conf $HOME/.tmux.conf

echo "installing qemu.."
brew install qemu

echo "installing helium.."
brew install --cask helium-browser

echo "installing ghostty.."
brew install --cask ghostty
ln -sfn $HOME/Code/setup/ghostty $HOME/.config/

echo "installing Iosevka font.."
brew install --cask font-iosevka-term-nerd-font

echo "installing claude code.."
brew install --cask claude-code

echo "installing github cli.."
brew install gh
gh auth login
