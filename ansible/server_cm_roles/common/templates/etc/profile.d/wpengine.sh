## {{ ansible_managed }}
export HISTTIMEFORMAT="%Y%m%d %T "

{% if is_vagrant %}
# https://github.com/wpengine/server-cm/pull/3532
tty -s && mesg n
{% else %}
mesg n
{% endif %}

# Include /usr/local/bin in PATH
export PATH=/usr/local/bin:$PATH

# Set global WP CLI stuff
export WP_CLI_CONFIG_PATH=/nas/wp/www/wp-cli.yml
export WP_CLI_CACHE_DIR=/tmp/wp-cli/cache

alias ms-cli='sudo /etc/wpengine/bin/ms-cli.phar'
alias mv='mv -i'
alias cp='cp -i'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'

function wpe()
{
    cd /nas/content/live/$1
}

function li()
{
    sudo /nas/wp/ec2/cluster list-instances {{ my.cluster.id }} | sort -k 3
    echo 'Note: Do not log into any storage servers unless specifically directed!'
}
