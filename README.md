seashell
========

Seashell is the basis for a dotfile management repo. Clone it, commit your
dotfiles to it, and you're done.

It doesn't depend on anything esoteric, just good old fashioned git, bash,
and GNU make. The unit tests depend on shutil2.

Features
--------

* Keeps your `$HOME` free of unnecessary git files (.git, .gitignore,
  .gitmodules, etc)
* Permits arbitrary directory structure (e.g. a/b/c will get moved to ~/a/b/c,
  creating any missing directories)
* The repo can live anywhere (e.g. ~/Dropbox/.dotfiles)
* The dotfiles can be exported anywhere (e.g.
  `sudo make install DST_ROOT=/home/$someone_else`)

Setup
-----

```sh
git clone --origin seashell https://github.com/staticshock/seashell ~/.dotfiles
cd ~/.dotfiles
mv ~/.bashrc ~/.vimrc .  # See below for fancy alternatives
make install  # Symlink them from the home directory
git add .*
git commit
git remote add origin https://github.com/$you/dotfiles.git
git push origin master
```

Instead of `mv ~/.bashrc .` you could run `make import`, which copies the
dotfiles from your home directory, as well as most of the directories with a
leading dot. Run it as `make import --dry-run` to see what would happen. Tune
it by overriding `EXPORT` in Makefile.conf, or just don't worry about it and
import things manually.

Usage
-----

Once you're set up, moving dotfiles between systems is a bit like installing a
package from source:

```sh
git clone https://github.com/$you/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make  # Clones submodules, runs misc setup actions
make install  # Creates symlinks in your home directory
```

By default, `make install` exports:

* Any top-level file or directory starting with a dot (.*), except for git
  files (e.g. .gitignore) and the .ssh dir (see below)
* Anything in .ssh. The default behavior is not to export the .ssh dir, but the
  files under it
* Anything that ends in *.export (this is checked recursively!)

You can modify all this in Makefile.conf.

Multiple sets of files can be managed in the same repo. Just put them into
different subdirectories (e.g. home/, work/) and provide a source root when
installing:

```sh
make install SRC_ROOT=home
```

Likewise, you can always test what gets exported by providing a dummy
destination root:

```sh
mkdir tmp
make install DST_ROOT=tmp
tree -a tmp
```

If you'd like to copy the files back and forth instead of symlinking
everything, you can do that too. Your friends are `make install RSYNC=y` and
`make import`.

**Warning:** `make import` will attempt to use `rsync --del` when importing
directory items. Commit your local changes first.

Submodules, Mixins, and Patches
-------------------------------

Adding submodules:

```sh
git submodule add https://github.com/robbyrussell/oh-my-zsh .oh-my-zsh
make install
```

Exporting a fraction of a submodule can be accomplished with a mixin:

```sh
git submodule add https://github.com/tpope/vim-pathogen mixins/vim-pathogen
mkdir -p .vim/autoload
ln -s {mixins/vim-pathogen,.vim}/autoload/pathogen.vim
make install
```

If a submodule has a bug, and you have a patch, you can put it into
patches/<submodule-path> and `make` will apply it.

Synchronizing
-------------

Fetching and installing upstream changes to your dotfiles: `make update`.

Adding an alias for the update process to ~/.bashrc:

```sh
echo "alias dotfiles-update='make -C ~/.dotfiles update'" >> ~/.bashrc
exec bash
dotfiles-update
```

Limitations
-----------

* Not tested on Windows. Probably won't work. No reason it would.
* Not tested on OSX. It's got a chance, though.
* Not tested on Haiku. I know, right?
