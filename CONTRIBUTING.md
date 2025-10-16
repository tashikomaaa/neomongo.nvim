# Contributing to neomongo.nvim

Thanks for your interest in contributing to **neomongo.nvim** 💜  
This document explains how to set up your environment, make changes, and submit pull requests.

---

## 🧰 Project Overview

**neomongo.nvim** is a Neovim plugin that provides integration with MongoDB.  
It aims to offer a modern, developer-friendly experience for exploring databases and running queries directly from Neovim.

---

## 🏗️ Development Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/tashikomaaa/neomongo.nvim.git
   cd neomong.nvim
   ```

2. **Install dependencies**

   You’ll need:
   - Neovim ≥ 0.9
   - Lua ≥ 5.1 (or the version embedded in Neovim)
   - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
   - Optionally: [stylua](https://github.com/JohnnyMorganz/StyLua) for formatting

3. **Run the plugin locally**

   You can load your local copy in Neovim using `:set runtimepath+=/path/to/neomongo.nvim`

4. **Run tests**

   If you’ve added or modified code, make sure all tests pass:

   ```bash
   make test
   ```

   or directly via Lua:
   ```bash
   lua tests/init.lua
   ```

---

## 🧑‍💻 Coding Guidelines

- Follow **Lua best practices**.
- Use **Stylua** for code formatting:

  ```bash
  make format
  ```

- Keep commits atomic and meaningful.
- Write **clear commit messages** (use the [Conventional Commits](https://www.conventionalcommits.org/) format if possible):
  ```
  feat(core): add support for async query execution
  fix(ui): prevent crash when no database is selected
  ```

---

## 🧪 Testing

- Add tests for new features or bug fixes under `tests/`.
- Prefer unit tests over integration tests when possible.
- Use **plenary.test_harness** or similar frameworks.

---

## 🚀 Submitting a Pull Request

1. **Create a new branch**
   ```bash
   git checkout -b feat/my-feature
   ```

2. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: short description"
   ```

3. **Push and open a PR**
   ```bash
   git push origin feat/my-feature
   ```
   Then go to GitHub and open a pull request.

---

## 🧩 Code Review Process

- All pull requests are reviewed for:
  - Code clarity
  - Style consistency
  - Test coverage
  - Documentation completeness

- Expect feedback or small requested changes before merge.

---

## 📜 Licensing and Attribution

By contributing, you agree that your code will be licensed under the same license as the project (MIT).

---

## ❤️ Thank You

Your contributions make **neomongo.nvim** better for everyone.  
Every bug fix, test, or idea helps shape a better developer experience!
