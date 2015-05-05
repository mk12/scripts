#!/bin/bash

# This script compiles my blog and puts the HTML in my website directory.

name=$(basename "$0")
usage="usage: $name [-h]"

if [[ $1 == "-h" || $1 == "--help" ]]; then
	echo "$usage"
	exit 0
fi

blog=~/icloud/blog
dest=~/Sites/mk/blog
partial_dir=$blog/themes/equanimity/layouts/partials

# The head.html file used for development has a different styles.css path (it
# uses the symlinks I created in the public folder). For deployment, it should
# use the same CSS file as the rest of the website.
mv "$partial_dir/head.html" "$partial_dir/head-dev.html"
mv "$partial_dir/head-deploy.html" "$partial_dir/head.html"
hugo -s "$blog" -d "$dest"
mv "$partial_dir/head.html" "$partial_dir/head-deploy.html"
mv "$partial_dir/head-dev.html" "$partial_dir/head.html"

files="$(find "$dest/post" -type f -name "index.html")"

for f in $files; do
	fmap.sh "inline_svg $dest/images" $f
done

if [[ $1 == "clean" ]]; then
	mv $dest/images/*.svg ~/.Trash
fi

echo "Don't forget to change the post date!"
