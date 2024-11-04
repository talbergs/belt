#!/usr/bin/env bash
#| Check translation strings.
#| Script must be run from within git repo.
#|
#| Program usage:
#|    check-strings <sha-then> <sha-now>
#|
#| Examples:
#|    * Last commit checked.
#|    $~ check-strings $(git rev-parse HEAD^) $(git rev-parse HEAD)
#|
#|    * Any commit checked, by revrapsing it's parent.
#|    $~ check-strings $(git rev-parse <sha>^) <sha>
#|    
#|    * Changes in this branch
#|    $~ check-strings $(git rev-parse <sha>^) <sha>
#|
#| Known issues:
#|    * If you have merged an "updated to latest from .." you will get inherited changes.
#|    * Correct output is possible by providing most recent merge right sha as first argument like so:
#|    * ~$ check-strings $(git log --merges -n 1 | grep -e "^Merge" | awk '{print $3}') HEAD
#|    * See translation strings that have newlines are missed, because of egrep in last line of script. For now I think about rewriting egrep into sed or awk, because I did not find any gettext flags to do "\n| normalization .. see: https://www.gnu.org/software/gettext/manual/gettext.html
[[ $1 == -h ]] && grep '^#|' $0 | sed 's/^#//' && exit 0
[[ $# -ne 2 ]] && grep '^#|' $0 | sed 's/^#//' && exit 1

git rev-parse $@ 1> /dev/null || exit 2

then_ref=$1
now_ref=$2

rm -rf /tmp/_chstr
mkdir /tmp/_chstr

# $1 <commit-ish>
# $? stdout
mk_pot() {
    git archive $1 > /tmp/_chstr/$1.tar
    tar -xf /tmp/_chstr/$1.tar --one-top-level=/tmp/_chstr/$1
    cd /tmp/_chstr/$1
    find /tmp/_chstr/$1 -type f -name "*.php" > /tmp/_chstr/$1/_phpfiles
    xgettext \
        --files-from=_phpfiles \
        --output=- \
        --keyword=_n:1,2 \
        --keyword=_s \
        --keyword=_x:1,2c \
        --keyword=_xs:1,2c \
        --keyword=_xn:1,2,4c \
        --from-code=UTF-8 \
        --language=php \
        --no-wrap \
        --sort-output \
        --no-location \
        --omit-header
}

jira_fmt() {
    exec 8<>/tmp/_chstr/$then_ref-$now_ref-removed
    exec 9<>/tmp/_chstr/$then_ref-$now_ref-added

    echo "Strings added:" >&9;
    echo "Strings deleted:" >&8;

    while IFS= read line; do
        fd=8 && [[ $line =~ ^\< ]] || fd=9

        echo "${line}" |
        sed -r '/[<>] msgctxt/ {:a;N;s/[<>] msgctxt "(.+)"\n[<>] msgid "(.+)"/- _\2_ *context:* _\1_/g}' | \
        sed -r 's/^(<|>) msgid(_plural){0,1} "/- _/g' | \
        sed -r 's/"$/_/g' | \
        sed -r 's/\\"/"/g' \
            >&$fd
    done

    diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/8 /dev/fd/9
    echo
    diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/9 /dev/fd/8

    exec 9>&-
    exec 8>&-
}

diff <(mk_pot $then_ref) <(mk_pot $now_ref) | \
    egrep '[<>] (msgid|msgctxt)' | jira_fmt
