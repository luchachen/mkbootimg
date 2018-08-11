#!/system/bin/sh
/system/bin/touch /dev/x
/system/bin/cp -rd --preserve=all /system/etc/ /dev/
/system/bin/sed -i -e 's/secure=1/secure=0/' -e 's/ro.debuggable=0/ro.debuggable=1/' /dev/etc/prop.default
/system/bin/echo ''  > /dev/etc/selinux/plat_and_mapping_sepolicy.cil.sha256
/system/bin/echo -n '/sbin/adbd    u:object_r:adbd_exec:s0
/sbin/init    u:object_r:init_exec:s0
/sbin/init\.sh u:object_r:init_exec:s0
' >> /dev/etc/selinux/plat_file_contexts
/system/bin/cat /sbin/su.cil >> /dev/etc/selinux/plat_sepolicy.cil
/system/bin/cat /sbin/dontauditsu.cil >> /dev/etc/selinux/plat_sepolicy.cil

/system/bin/mount -o bind  /dev/etc/ /system/etc/
