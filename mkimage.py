"""

#define BLK_SIZE          512
typedef union
{
    struct
    {
        unsigned int magic;     /* partition magic */
        unsigned int dsize;     /* partition data size */
        char name[32];          /* partition name */
        unsigned int maddr;     /* partition memory address */
    } info;
    unsigned char data[512];
} part_hdr_t;

"""
PART_MAGIC    =    0x58881688
mkimage_header = "<2I 28s I 472s"
