#~/bin/bash
# bundle codebase for Claude

NOW=$(date "+%Y-%m-%d_%H-%M-%S")

tar -czvf codebase-$NOW.tar.gz src/