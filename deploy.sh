#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

echo "=== Step1. build hugo"
# Build the project.
# hugo -t <your theme>
hugo -t PaperMod

echo "=== Step2. commit & push public directory"
# Go To Public folder, sub module commit
# shellcheck disable=SC2164
cd public
# Add changes to git.
git add .

# Commit changes.
msg="rebuilding yosong6729 blog, `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin main

echo "=== Step3. commit & push blog directory"
# Come Back up to the Project Root
cd ..

# blog repository Commit & Push
git add .

msg="rebuilding yosong6729 blog, `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

git push origin main