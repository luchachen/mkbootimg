#!/system/bin/sh
/system/bin/touch /dev/x
/system/bin/cp -rd --preserve=all /system/etc/ /dev/
/system/bin/sed -i -e 's/secure=1/secure=0/' -e 's/ro.debuggable=0/ro.debuggable=1/' /dev/etc/prop.default
/system/bin/cat <<EOF  > /dev/etc/selinux/plat_and_mapping_sepolicy.cil.sha256
EOF
/system/bin/cat <<EOF >> /dev/etc/selinux/plat_sepolicy.cil
(typepermissive adbd)
(typepermissive shell)
(typepermissive su)
EOF
/system/bin/mount -o bind  /dev/etc/ /system/etc/
