# Edit Nginx config and run syntax test
cmd_edit_nginx() {
    local edit_status test_status

    sudo vi /etc/nginx
    edit_status=$?

    sudo nginx -t
    test_status=$?

    if [[ $edit_status -ne 0 ]]; then
        return "$edit_status"
    fi

    return "$test_status"
}

cmd_edit_nginx "$@"
unset -f cmd_edit_nginx
