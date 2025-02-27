#!/usr/bin/bash

set -e

PROJECT_PATH="$1"
PROJECT_NAME="$2"

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

if [[ -z "$PROJECT_PATH" || -z "$PROJECT_NAME" ]]
then
    echo "Usage: $0 -p project_path -n project_name"
    echo "Both project path and project name are required."
    exit 1
fi

if [ -e "$PROJECT_PATH/$PROJECT_NAME" ]
then
    echo "Project directory already exists."
    exit 1
fi

# Create project directory
echo "Creating directories."
mkdir -p "$PROJECT_PATH/$PROJECT_NAME/$PROJECT_NAME"
cd "$PROJECT_PATH/$PROJECT_NAME"
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
    echo "Superuser authentication is required to make the pre-commit hook executable."
    if ! sudo -v
    then
        echo "Authentication failed."
        exit 1
    fi
fi
sudo chmod +x .githooks/pre-commit

git config core.hooksPath .githooks

# Poetry setup
echo "Setting up poetry."
poetry init -n --name="$PROJECT_NAME"
echo "# $PROJECT_NAME" > README.md

echo "Adding linters."
cat <<'EOF' >> pyproject.toml


[tool.poetry.group.linters]
optional = true


[tool.poetry.group.linters.dependencies]


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
line_length = 120
skip_string_normalization = true


[tool.isort]
profile = 'black'
line_length = 120


[tool.coverage.report]
exclude_also = [
    "if TYPE_CHECKING:",
    ]


EOF

poetry add -q --group linters "${LINTERS[@]}"
poetry install -q --with linters

# VSCode setup
echo "Creating VSCode settings."
mkdir .vscode

POETRY_BASE_PATH=$(poetry env info -p)
cat <<EOF > .vscode/settings.json
{
    "python.defaultInterpreterPath": "$POETRY_BASE_PATH/bin/python",
    "black-formatter.path": [
        "$POETRY_BASE_PATH/bin/black"
    ],
    "flake8.path": [
        "$POETRY_BASE_PATH/bin/flake8"
    ],
    "isort.check": true,
    "isort.path": [
        "$POETRY_BASE_PATH/bin/isort"
    ],
    "[python]": {
        "editor.defaultFormatter": "ms-python.black-formatter",
        "editor.formatOnSave": true
    }
}
EOF

# Initial commit
echo "Making an initial commit."
git add -A
git commit -q -m "Initial project setup" --no-verify

echo -e "\nDone!"