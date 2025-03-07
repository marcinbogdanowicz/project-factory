# Project factory script

This is a convenvience script I made for personal use, which might be helpful to others. 

Feel free to adjust it to your needs!

## Prerequisites

- poetry
- git
- docker & docker compose

VSCode is not required, but the script will create settings.json for VSC. I'm using the following plugins:
- Black Formatter by Microsoft,
- Flake8 by Microsoft,
- isort by Microsoft.

## Usage

**Base usage**

```
./factory.sh /parent/directory/path/ project-name
```

The script will:
- create:
    - `/parent/directory/path/project-name/` directory,
    - `/parent/directory/path/project-name/project-name/` directory,
    - `/parent/directory/path/project-name/project-name/__init__.py` file,
- initialize a git repo,
- add a .gitignore file,
- create a pre-commit githook script which runs autoflake, black, flake8 and isort on commited files,
- initialize poetry environment,
- install linters and add their configuration,
- add .vscode settings so that Python, black, flake8 and isort executables from the project are used by VSC plugins,
- make an initial git commit.

**Additional options**

```
./factory.sh /parent/directory/path/ project-name --line-length=80
```

Using `--line-length=*` or `-l=*` will set the desired line length for black and isort formatters and add a vertical line
in VSCode at the given character.

```
./factory.sh /parent/directory/path/ project-name --docker
```

Using `--docker` or `-d` flag will create a development docker environment:
- create `/parent/directory/path/project-name/docker/` directory
- create a base `Dockerfile.dev`
- create an empty `entrypoint.sh` (with only `exec "$@"` command)
- create a `docker-compose.yml` file with a placeholder command and basic setup.