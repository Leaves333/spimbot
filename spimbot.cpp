// 4 byte struct for encoding a slab
typedef struct slab_encoding_t
{
    // ROW and COL of the TILE for the CENTER of the slab
    unsigned int pos_row : 8;
    unsigned int pos_col : 8;
    // 0 when bot0 owns, 1 when bot1 owns, undefined when not locked
    unsigned int owner : 1;
    // 0 when not locked, 1 when locked (by either bot)
    unsigned int locked : 1;
    // padding bits
    unsigned int pad : 14;
} slab_encoding_t;

#define MAX_SLABS 20;
typedef struct slab_info_t
{
    // how many slabs are written
    int length;                     // 4 bytes
    // array of all slabs
    // the order of the slabs is undefined, but will not change throughout the scenario
    slab_encoding_t metadata[MAX_SLABS];    // 20 * 4 bytes
} slab_info_t;
// 84 byte struct
