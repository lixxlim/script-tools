# Edit Nginx configuration
edit_nginx() {
    sudo vi /etc/nginx || return $?
    sudo nginx -t
}

edit_nginx "$@"
unset -f edit_nginx
