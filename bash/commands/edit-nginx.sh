# Edit Nginx configuration
edit_nginx() {
    sudo vi /usr/local/etc/nginx/nginx.conf
}

edit_nginx "$@"
unset -f edit_nginx
