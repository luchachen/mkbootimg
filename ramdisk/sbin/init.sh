#!/system/bin/sh
PATH=/sbin:/system/sbin:/system/bin:/system/xbin:/vendor/bin:/vendor/xbin
cp -rd --preserve=all /system/etc/ /dev/
sed -i -e 's/secure=1/secure=0/' -e 's/ro.debuggable=0/ro.debuggable=1/' /dev/etc/prop.default
echo ''  > /dev/etc/selinux/plat_and_mapping_sepolicy.cil.sha256
echo -n '/sbin/adbd    u:object_r:adbd_exec:s0
/sbin/init    u:object_r:init_exec:s0
/sbin/init\.sh u:object_r:init_exec:s0
' >> /dev/etc/selinux/plat_file_contexts
cat /sbin/su.cil /sbin/dontauditsu.cil >> /dev/etc/selinux/plat_sepolicy.cil

mount -o bind  /dev/etc/ /system/etc/
