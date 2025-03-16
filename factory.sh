#!/usr/bin/bash

set -e

function show_usage {
    echo "Usage: $0 project_path project_name"
    echo "Optional flags:"
    echo "  -n, --no-commit: Do not make an initial commit."
    echo "  -d, --docker: Create a docker compose setup."
}

LINTERS=(
    "autoflake"
    "autopep8"
    "black"
    "flake8"
    "flake8-black"
    "flake8-bugbear"
    "flake8-comprehensions"
    "flake8-pyproject"
    "flake8-return"
    "flake8-tidy-imports"
    "flake8-implicit-str-concat"
    "flake8-simplify" 
    "isort"
)

PROJECT_PATH="$1"
PROJECT_NAME="$2"

if [[ -z "$PROJECT_PATH" || -z "$PROJECT_NAME" ]]
then
    echo -e "Missing project_path and project_name arguments!\n"
    show_usage;
    exit 1
fi

shift 2

CREATE_DOCKER_SETUP="false"
LINE_LENGTH="120"
POETRY="false"

for i in "$@"
do
    case $i in
        -d|--docker)
        CREATE_DOCKER_SETUP="true"
        shift
        ;;
        -l=*|--line-length=*)
        LINE_LENGTH="${i#*=}"
        shift
        ;;
        -p|--poetry)
        POETRY="true"
        shift
        ;;
        -h|--help)
        show_usage
        exit 0
        ;;
        *)
        ;;
    esac
done

if [ -e "$PROJECT_PATH/$PROJECT_NAME" ]
then
    echo "Project directory already exists."
    exit 1
fi

# Create project directory
echo "Creating directories."
mkdir -p "$PROJECT_PATH/$PROJECT_NAME-project/$PROJECT_NAME"
cd "$PROJECT_PATH/$PROJECT_NAME-project"
touch "$PROJECT_NAME/__init__.py"

# Git setup
echo "Initializing git repository."
git init -q

cat <<'EOF' >> .gitignore
__pycache__/
__pypackages__/
.ipython/
a.py
.coverage
.vscode
.env
venv
EOF

mkdir .githooks
cat <<'EOF' > .githooks/pre-commit
#!/usr/bin/bash


# autoflake
echo "Checking unused imports and variables with autoflake..."
CHECK="python -m autoflake --in-place"
python_files_to_check=$(git diff --cached --name-only --diff-filter=d | grep -E '\.(py)$' | tr '\n' ' ')

status=0
for file in $python_files_to_check; do
  committed_content=$(cat "$file")

  $CHECK "$file" || status=1

  if [ "$(cat "$file")" != "$committed_content" ]; then
    echo "Autoflake removed unused imports in $file. Staging the file."
    git add "$file"
  fi
done

if [ "$status" != 0 ]; then
  exit $status
fi

# black
echo "Checking code with black..."
CHECK="python -m black --config=./pyproject.toml"
python_files_to_check=$(git diff --cached --name-only --diff-filter=d | grep -E '\.(py)$' | tr '\n' ' ')

status=0
for file in $python_files_to_check; do
  committed_content=$(cat "$file")

  $CHECK "$file" || status=1

  if [ "$(cat "$file")" != "$committed_content" ]; then
    echo "Black formated code in $file. Staging the file."
    git add "$file"
  fi
done

if [ "$status" != 0 ]; then
  exit $status
fi


# flake8
echo "Checking code with flake8..."
CHECK="python -m flake8"
python_files_to_check=$(git diff --cached --name-only --diff-filter=d | grep -E '\.(py)$' | tr '\n' ' ')

status=0
for file in $python_files_to_check; do
  $CHECK "$file" || status=1
done

if [ "$status" != 0 ]; then
  exit $status
fi


# isort
echo "Checking imports with isort..."
CHECK="python -m isort --settings-file=./pyproject.toml"
python_files_to_check=$(git diff --cached --name-only --diff-filter=d | grep -E '\.(py)$' | tr '\n' ' ')

status=0
for file in $python_files_to_check; do
  committed_content=$(cat "$file")

  $CHECK "$file" || status=1

  if [ "$(cat "$file")" != "$committed_content" ]; then
    echo "isort sorted imports in $file. Staging the file."
    git add "$file"
  fi
done

if [ "$status" != 0 ]; then
  exit $status
fi
EOF


if ! sudo -n true 2>/dev/null
then
    echo "Superuser authentication is required for making scripts executable."
    if ! sudo -v
    then
        echo "Authentication failed."
        exit 1
    fi
fi
sudo chmod +x .githooks/pre-commit

git config core.hooksPath .githooks

if [ $POETRY == "true" ]
then
# Poetry setup
echo "Setting up poetry env."
poetry init -n --name="$PROJECT_NAME"
echo "# $PROJECT_NAME" > README.md

echo "Adding linters."
cat <<EOF >> pyproject.toml


[tool.poetry.group.dev]
optional = true


[tool.poetry.group.dev.dependencies]


EOF

poetry add -q --group dev "${LINTERS[@]}"
poetry install -q --with dev

# VSCode setup
echo "Creating VSCode settings."
mkdir .vscode

if [ $POETRY == "true" ]
then
  EXECUTABLES_BASE_PATH=$(poetry env info -p)
else
  EXECUTABLES_BASE_PATH="$(pwd)/venv"
fi

cat <<EOF > .vscode/settings.json
{
    "python.defaultInterpreterPath": "$EXECUTABLES_BASE_PATH/bin/python",
    "black-formatter.path": [
        "$EXECUTABLES_BASE_PATH/bin/black"
    ],
    "flake8.path": [
        "$EXECUTABLES_BASE_PATH/bin/flake8"
    ],
    "isort.check": true,
    "isort.path": [
        "$EXECUTABLES_BASE_PATH/bin/isort"
    ],
    "[python]": {
        "editor.defaultFormatter": "ms-python.black-formatter",
        "editor.formatOnSave": true
    },
    "editor.rulers": [
        ${LINE_LENGTH}
    ],
}

EOF
else
# Setup venv
echo "Setting up venv."
python3 -m venv venv
source venv/bin/activate
pip install -q "${LINTERS[@]}"
pip freeze > requirements.txt
fi

# Setup linters config
cat <<EOF >> pyproject.toml


[tool.flake8]
ignore = [
    # Do not call getattr(x, 'attr'), instead use normal property access: x.attr
    'B009',
    # Do not call setattr(x, 'attr', val), instead use normal property access: x.attr = val
    'B010',
    # assertRaises(Exception) and pytest.raises(Exception) should be considered evil
    'B017',
    # Abstract base class has methods, but none of them are abstract.
    'B024',
    # indentation is not a multiple of four (comment)
    'E114',
    # unexpected indentation (comment)
    'E116',
    # whitespace before ‘,’, ‘;’, or ‘:’
    'E203',
    # missing whitespace around operator
    'E225',
    # missing whitespace around arithmetic operator
    'E226',
    # missing whitespace around bitwise or shift operator
    'E227',
    # at least two spaces before inline comment
    'E261',
    # block comment should start with ‘# ‘
    'E265',
    # line too long (82 > 79 characters)
    'E501',
    # missing explicit return at the end of function able to return non-None value.
    'R503',
    # unnecessary variable assignment before return statement.
    'R504',
    # unnecessary else after return statement.
    'R505',
    # unnecessary else after raise statement.
    'R506',
    # Use a single if-statement instead of nested if-statements
    'SIM102',
    # Use any(...)
    'SIM110',
    # Combine conditions via a logical or to prevent duplicating code
    'SIM114',
    # Split string directly if only constants are used
    'SIM905',
    # Use dict.get(key)
    'SIM908',
    # line break before binary operator
    'W503',
    # line break after binary operator
    'W504'
]
exclude = [
    '.git',
]
banned-modules = '''
    typing.Optional = Use | None
    typing.List = Use list
    typing.Dict = Use dict
    typing.Set = Use set
    typing.Tuple = Use tuple
    typing.Union = Use |
'''
extend-immutable-calls = ['Depends']
max-complexity = 15
ban-relative-imports = true

[tool.black]
line_length = ${LINE_LENGTH}
skip_string_normalization = true


[tool.isort]
profile = 'black'
line_length = ${LINE_LENGTH}

EOF

# Docker setup
if [ "$CREATE_DOCKER_SETUP" == "true" ]
then
echo "Creating docker setup."

mkdir docker

cat <<'EOF' > docker/entrypoint.sh
#!/usr/bin/bash

exec "$@"

EOF

cat <<EOF > docker/Dockerfile.dev
FROM public.ecr.aws/docker/library/python:3.12
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1

WORKDIR /app

EOF

if [ $POETRY == "true" ]
then
cat <<EOF >> docker/Dockerfile.dev
RUN pip install poetry
RUN poetry config virtualenvs.create false
COPY pyproject.toml poetry.lock /app
RUN poetry install --no-root
EOF
else
cat <<EOF >> docker/Dockerfile.dev
COPY requirements.txt /app
RUN pip install -r requirements.txt
EOF
fi

cat <<EOF >> docker/Dockerfile.dev
COPY ./docker/entrypoint.sh /app
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]

EOF

cat <<EOF > .dockerignore
__pycache__
.dockerignore

EOF

cat <<EOF > docker-compose.yml
services:
  ${PROJECT_NAME}:
    build:
      context: .
      dockerfile: docker/Dockerfile.dev
    ports:
      - 8000:8000
    volumes:
      - ./${PROJECT_NAME}:/app/${PROJECT_NAME}
    command: echo "Please implement the container command!"

EOF

mkdir scripts
cat <<EOF > scripts/command.sh
#!/usr/bin/bash

docker compose run --rm -w /app ${PROJECT_NAME} bash -c "\$@"

EOF

chmod +x scripts/command.sh
fi

# Initial commit
echo "Making an initial commit."
git add -A
git commit -q -m "Initial project setup" --no-verify

echo -e "\nDone!"
