# Project factory script

This is a convenvience script I made for personal use, which might be helpful to others. Feel free to adjust it to your needs!

## Usage:

```
./factory.sh /parent/directory/path/ project-name
```

The script will:
- create directory `/parent/directory/path/project-name/` and `/parent/directory/path/project-name/project-name/`,
- initialize a git repo,
- add a .gitignore file,
- create a pre-commit githook script which runs autoflake, black, flake8 and isort on commited files,
- initialize poetry environment,
- install linters and add their configuration,
- add .vscode settings so that Python, black, flake8 and isort executables from the project are used by VSC plugins,
- make an initial git commit.