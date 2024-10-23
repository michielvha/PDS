# Architecture

`bpkg` (Bash Package Manager) is a lightweight package manager designed specifically for Bash scripts and utilities. It aims to provide a simple way to manage Bash packages and reusable scripts, much like how `npm` works for Node.js or `NuGet` works for PowerShell.

### Key Features of `bpkg`:

1. **Install Bash Packages**: 
   `bpkg` allows you to install Bash packages hosted in Git repositories (usually on GitHub). It clones the repository and makes the package available on your system.

2. **Manage Dependencies**:
   Bash scripts or utilities can specify dependencies, which `bpkg` will resolve and install automatically.

3. **Version Control**:
   Each package can specify its version, and you can install specific versions of packages.

4. **Works from Git**:
   `bpkg` uses Git as its backend. When you install a package, `bpkg` will clone the repository (or a specific branch/tag) and handle the installation of the scripts.

5. **Simple Installation**:
   `bpkg` makes it easy to install new Bash utilities with a single command.

6. **Cross-platform**:
   Since it is just a Bash utility, `bpkg` can be used across different Unix-based systems (Linux, macOS, etc.).

---

### Installing `bpkg`:

`bpkg` itself is a Bash script, so installing it is straightforward.

```bash
git clone https://github.com/bpkg/bpkg.git ~/.bpkg
echo 'export PATH="$HOME/.bpkg/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

This will clone the `bpkg` repository into your home directory and add it to your `PATH` so you can start using it immediately.

---

### Using `bpkg`:

#### 1. **Installing Packages**:
Once `bpkg` is installed, you can install Bash packages from GitHub like this:

```bash
bpkg install <username>/<repository>
```

For example, installing a package called `json.sh` from the repository:

```bash
bpkg install dominictarr/json.sh
```

This will download the Bash script, resolve any dependencies, and install it in your local environment.

#### 2. **Running Installed Packages**:
The installed packages are placed in your `~/.bpkg/bin` folder, which is added to your `PATH`. This means you can run the installed scripts or utilities just like any other system command.

#### 3. **Package Structure**:
Bash packages that work with `bpkg` usually follow a simple structure. They typically have:

- **`bpkg.json`**: A file that describes the package, including metadata such as version, dependencies, and description.
- **Executable Scripts**: The actual Bash scripts or utilities to be used.

Here’s an example `bpkg.json`:

```json
{
  "name": "my-bash-package",
  "version": "1.0.0",
  "description": "A simple bash utility",
  "dependencies": {
    "user/dependency-repo": "1.0.0"
  }
}
```

#### 4. **Listing Installed Packages**:
You can list all the packages that you’ve installed with `bpkg`:

```bash
bpkg list
```

#### 5. **Updating and Uninstalling Packages**:
To update an installed package to the latest version:

```bash
bpkg update <username>/<repository>
```

To uninstall a package:

```bash
bpkg remove <username>/<repository>
```

---

### Publishing Your Own Bash Package:

If you want to create your own package and publish it for use with `bpkg`, the process is simple:

1. Create a GitHub repository.
2. Write your Bash script(s).
3. Create a `bpkg.json` file with metadata about your package.
4. Add your GitHub repository to the bpkg ecosystem by making it publicly available.

Once your package is ready, others can install it directly from your GitHub repo using `bpkg install`.

---

### Limitations of `bpkg`:

- **Smaller Ecosystem**: Since `bpkg` is a niche tool for Bash scripts, it doesn't have as large a package repository as other package managers like `npm` or `pip`.
- **GitHub Dependency**: It relies heavily on Git and GitHub, so you need Git installed and a stable internet connection to use it.
- **No Central Registry**: Unlike `NuGet` or `npm`, there’s no central repository or registry for `bpkg`. Instead, it pulls directly from GitHub repositories, which can make it harder to discover new packages.

---

### Alternatives to `bpkg`:
- **Homebrew**: While Homebrew is not specific to Bash scripts, it’s a popular package manager for macOS and Linux. It can install binaries and some shell scripts.
- **APT/YUM/PKG**: The native package managers for Linux distributions can also manage scripts or utilities that are part of the system repositories.


