#/bin/bash
cd `dirname $0`

find ./* -name '*.md' -print0 | while read -r -d '' file
do
  echo "[1] Converting Markdown to reST : $file"
  pandoc -f markdown -t rst "$file" -o "${file%%.md}.rst" # translate Markdown to reST
done

find ./* -name '*.rst' -print0 | while read -r -d '' file
do
  echo "[2] Processing reST code : $file"
  sed -i.bak -e 's/\.\.\ code:: math/.. math::/g' "${file}" # substitution for code hilighting
  sed -i.bak -e 's/\.\.\ code::/.. code-block::/g' "${file}" # substitution for code hilighting
done

echo "[3] Building Documantation"
make html

echo "[4] Removing backup & reST files"
find ./* -name '*.bak' -type f | xargs rm
find ./* -name '*.md' -print0 | while read -r -d '' file
do
  rm ${file%%.md}.rst
done

echo "[5] Copying all files to docs/"
rm -r docs/*
cp -r build/html/* docs/
touch docs/.nojekyll

echo "[6] Done."
