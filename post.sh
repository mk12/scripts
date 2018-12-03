#!/bin/bash

# This script compiles my blog and puts the HTML in my website directory.
# With the "-p username", uses rsync to publish the blog.

name=$(basename "$0")
usage="usage: $name [-h] [-p | --publish USERNAME]"

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "$usage"
    exit 0
fi

blog=$BLOG
dest=~/Dropbox/Website/blog
partial_dir=$blog/themes/equanimity/layouts/partials

# Switch to the deployment head file.
echo '{{ partial "head-deploy.html" . }}' > "$partial_dir/head.html"

# Compile the blog and deploy it.
hugo -s "$blog" -d "$dest"

# Return to the development head file.
echo '{{ partial "head-dev.html" . }}' > "$partial_dir/head.html"

# Get all HTML files.
files="$(find "$dest/post" -type f -name "index.html")"

# Inline all SVG content (so that they can use the web fonts).
for f in $files; do
    fmap.sh "inline_svg $dest/images" $f
done

# The files here are not needed.
trash="$HOME/.Trash/post-$(date +%s)"
mkdir "$trash"
mv $dest/images/*.svg "$trash"
mv $dest/fonts "$trash"
mv $dest/js "$trash"
find $dest/categories -type d -mindepth 1 -prune -exec mv {} $trash \;

# Publish to the server.
if [[ $1 == "-p" || $1 == "--publish" ]]; then
    if [[ -z "$2" ]]; then
        echo "Usage: post.sh -p USERNAME"
        exit 1
    fi
    rsync -avz -e ssh --delete $dest/ \
        $2@ssh.phx.nearlyfreespeech.net:/home/public/blog \
        --exclude .DS_Store
fi

# I usually publish a few days after creating the Markdown file.
echo "Don't forget to change the post date!"
