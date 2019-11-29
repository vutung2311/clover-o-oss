#!/system/bin/sh

if [ "$1" = "boot_completed" ]; then
	setenforce 1;
fi

exit;

