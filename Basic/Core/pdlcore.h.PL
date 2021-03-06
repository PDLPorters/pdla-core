# -*-perl-*-

##############################
#
# Be sure to increment $pdl_core_version (about 20 lines below this note)
# if you change any prototypes or modify the Core structure!
#
##############################

use strict;
use Config;
use File::Basename qw(&basename &dirname);

require './Dev.pm'; PDLA::Core::Dev->import;
my $sym2type = PDLA::Core::Dev::load_Types();

# version 2 is for versions after PDLA 2.1.1
# version 4 has pdl_hard_copy included in the Core structure.
# version 6 is introduced after 2.4.2, due to the experimental
#   per-piddle bad values code (the BADVAL_PER_PDLA option)
# version 7 introduced for some changes to function prototypes
#   for pthreading (i.e. multi-threading) capabilities
# version 8 for beginning support for >2GiB piddles
# version 9 for STRLEN/Size_t/Off_t for mmap delete magic
# version 10 for 64bit index support (PDLA index datatype)
# version 11 for core cleanup (proto-PDLA-3)
# version 12 for PDLA_Anyval union data type (full 64bit support)
use vars qw( $pdl_core_version );
$pdl_core_version = 12;

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
my $file;
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($Config{'osname'} eq 'VMS' or
	    $Config{'osname'} eq 'OS2');  # "case-forgiving"

print "Extracting $file\n";
open OUT,">$file" or die "Can't create $file: $!";
chmod 0644, $file;

# In this section, perl variables will be expanded during extraction.
# You can use $Config{...} to use Configure variables.


print OUT <<'!NO!SUBS!';
/*
 * THIS FILE IS GENERATED FROM pdlcore.h.PL! Do NOT edit!
 */

#ifndef __PDLACORE_H
#define __PDLACORE_H

#include "EXTERN.h"   /* std perl include */
#include "perl.h"     /* std perl include */
#include "XSUB.h"  /* for the win32 perlCAPI crap */
#include "ppport.h"  /* include this AFTER XSUB.h */

#if defined(CONTEXT) && defined(__osf__)
#undef CONTEXT
#endif

#include "pdl.h"
#include "pdlthread.h"
/* the next one causes trouble in c++ compiles - exclude for now */
#ifndef __cplusplus
#include "pdlmagic.h"
#endif

!NO!SUBS!

print OUT "#define PDLA_CORE_VERSION $pdl_core_version\n";

print OUT <<'!NO!SUBS!' if ($^O =~ /MSWin/);
 
#define finite _finite
#include <float.h>

!NO!SUBS!

print OUT <<'!NO!SUBS!';

#define PDLA_TMP  0        /* Flags */
#define PDLA_PERM 1

#define BIGGESTOF(a,b) ( a->nvals>b->nvals ? a->nvals : b->nvals )
#define SVavref(x) (SvROK(x) && SvTYPE(SvRV(x))==SVt_PVAV)

/* Create portable NaN's with the NaN_float and NaN_double macros.
 * The end values are 7f to turn off sign bit to avoid printing "-NaN".
 * This produces QNaN's or quiet nan's on architectures that support it.
 *
 * The below uses IEEE-754, so it should be portable.  Also note the symmetry
 * which makes the bigendian vs little-endian issue moot.  If platforms should
 * arise which require further consideration, use the pdl function,
 * PDLA::Core::Dev::isbigendian() which returns a boolean value (a false value
 * garantees little-endian), and #ifdef's for exotic architectures.  You'll be
 * hard pressed to find an architecture that doesn't support ieee-754 but does
 * support NaN.  See http://en.wikipedia.org/wiki/NaN to understand why
 * this works. */
static const union {unsigned char c[4]; float f;}
   union_nan_float = {{0x7f, 0xff, 0xff, 0x7f}};
static const union {unsigned char c[8]; double d;}
   union_nan_double = {{0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f}};

/*  Use our own barf and our own warn.
 *  We defer barf (and warn) handling until after multi-threaded (i.e pthreading)
 *  processing is finished.
 *  This is needed because segfaults happen when perl's croak is called
 *  during one of the spawned pthreads for PDLA processing.
 */
#define barf PDLA->pdl_barf
#undef warn
#define warn PDLA->pdl_warn


typedef int Logical;

/*************** Function prototypes *********************/


/* pdlcore.c */

int     pdl_howbig (int datatype);           /* Size of data type (bytes) */
pdl*    SvPDLAV ( SV* sv );                   /* Map SV* to pdl struct */
void	SetSV_PDLA( SV *sv, pdl *it );	     /* Outputting a pdl from.. */
SV*     pdl_copy( pdl* a, char* option );     /* call copy method */
PDLA_Indx *    pdl_packdims ( SV* sv, int*ndims ); /* Pack dims[] into SV aref */
void    pdl_unpackdims ( SV* sv, PDLA_Indx *dims,  /* Unpack */
                         int ndims );
void*   pdl_malloc ( STRLEN nbytes );           /* malloc memory - auto free()*/

void pdl_makescratchhash(pdl *ret, PDLA_Anyval data);
PDLA_Indx pdl_safe_indterm(PDLA_Indx dsz, PDLA_Indx at, char *file, int lineno);
void pdl_barf(const char* pat,...); /* General croaking utility */
void pdl_warn(const char* pat,...); /* General warn utility */
PDLA_Indx av_ndcheck(AV* av, AV* dims, int level, int *datalevel);
pdl* pdl_from_array(AV* av, AV* dims, int type, pdl* p);

!NO!SUBS!

for my $in ( PDLA::Types::typesrtkeys() ) {

  (my $type = $sym2type->{$in}) =~ s/^PDLA_//;
  print OUT <<"!WITH!SUBS!";
PDLA_Indx pdl_setav_$type(PDLA_$type* pdata, AV* av,
	PDLA_Indx* pdims, PDLA_Long ndims, int level, PDLA_$type undefval, pdl *p);
!WITH!SUBS!
}

print OUT <<'!NO!SUBS!';

/* pdlapi.c */

void pdl_vaffinechanged(pdl *it, int what);
void pdl_trans_mallocfreeproc(struct pdl_trans *tr);
void pdl_make_trans_mutual(pdl_trans *trans);
void pdl_destroytransform_nonmutual(pdl_trans *trans,int ensure);

void pdl_vafftrans_free(pdl *it);
void pdl_vafftrans_remove(pdl * it);
void pdl_make_physvaffine(pdl *it);
void pdl_vafftrans_alloc(pdl *it);

pdl *pdl_null();
pdl *pdl_get_convertedpdl(pdl *pdl,int type);

void pdl_destroytransform(pdl_trans *trans,int ensure);

pdl *pdl_hard_copy(pdl *src);

#define pdl_new() pdl_create(PDLA_PERM)
#define pdl_tmp() pdl_create(PDLA_TMP)
pdl* pdl_external_new();
pdl* pdl_external_tmp();
pdl* pdl_create(int type);
void pdl_destroy(pdl *it);
void pdl_setdims(pdl* it, PDLA_Indx* dims, int ndims);
void pdl_reallocdims ( pdl *it,int ndims );  /* reallocate dims and incs */
void pdl_reallocthreadids ( pdl *it,int ndims );  /* reallocate threadids */
void pdl_resize_defaultincs ( pdl *it );     /* Make incs out of dims */
void pdl_unpackarray ( HV* hash, char *key, PDLA_Indx *dims, int ndims );
void pdl_print(pdl *it);
void pdl_dump(pdl *it);
void pdl_allocdata(pdl *it);

PDLA_Indx *pdl_get_threadoffsp(pdl_thread *thread); /* For pthreading */
void pdl_thread_copy(pdl_thread *from,pdl_thread *to);
void pdl_clearthreadstruct(pdl_thread *it);
void pdl_initthreadstruct(int nobl,pdl **pdls,PDLA_Indx *realdims,PDLA_Indx *creating,int npdls,
	pdl_errorinfo *info,pdl_thread *thread,char *flags, int noPthreadFlag );
int pdl_startthreadloop(pdl_thread *thread,void (*func)(pdl_trans *),pdl_trans *);
int pdl_iterthreadloop(pdl_thread *thread,int which);
void pdl_freethreadloop(pdl_thread *thread);
void pdl_thread_create_parameter(pdl_thread *thread,int j,PDLA_Indx *dims,
				 int temp);
void pdl_croak_param(pdl_errorinfo *info,int paramIndex, char *pat, ...);

void pdl_setdims_careful(pdl *pdl);
void pdl_put_offs(pdl *pdl,PDLA_Indx offs, PDLA_Anyval val);
PDLA_Anyval pdl_get_offs(pdl *pdl,PDLA_Indx offs);
PDLA_Anyval pdl_get(pdl *pdl,PDLA_Indx *inds);
void pdl_set_trans(pdl *it, pdl *parent, pdl_transvtable *vtable);

void pdl_make_physical(pdl *it);
void pdl_make_physdims(pdl *it);

void pdl_children_changesoon(pdl *it, int what);
void pdl_changed(pdl *it, int what, int recursing);
void pdl_separatefromparent(pdl *it);

void pdl_trans_changesoon(pdl_trans *trans,int what);
void pdl_trans_changed(pdl_trans *trans,int what);

void pdl_set_trans_childtrans(pdl *it, pdl_trans *trans,int nth);
void pdl_set_trans_parenttrans(pdl *it, pdl_trans *trans,int nth);

/* pdlhash.c */

pdl*    pdl_getcache( HV* hash );       /* Retrieve address of $$x{PDLA} */
pdl*    pdl_fillcache( HV* hash, SV* ref);       /* Fill/create $$x{PDLA} cache */
void    pdl_fillcache_partial( HV *hash, pdl *thepdl ) ;
SV*     pdl_getKey( HV* hash, char* key );  /* Get $$x{Key} SV* with deref */
void pdl_flushcache( pdl *thepdl );	     /* flush cache */

/* pdlconv.c */

void pdl_writebackdata_vaffine(pdl *it);
void pdl_readdata_vaffine(pdl *it);

void   pdl_swap(pdl** a, pdl** b);             /* Swap two pdl ptrs */
void   pdl_converttype( pdl** a, int targtype, /* Change type of a pdl */
                        Logical changePerl );
void   pdl_coercetypes( pdl** a, pdl **b, Logical changePerl ); /* Two types to same */
void   pdl_grow  ( pdl* a, PDLA_Indx newsize);   /* Change pdl 'Data' size */
void   pdl_retype( pdl* a, int newtype);      /* Change pdl 'Datatype' value */
void** pdl_twod( pdl* x );                    /* Return 2D pointer to data array */

/* pdlsections.c */

PDLA_Indx  pdl_get_offset(PDLA_Indx* pos, PDLA_Indx* dims, PDLA_Indx *incs, PDLA_Indx offset, int ndims);      /* Offset of pixel x,y,z... */
PDLA_Indx  pdl_validate_section( PDLA_Indx* sec, PDLA_Indx* dims,           /* Check section */
                           int ndims );
void pdl_row_plusplus ( PDLA_Indx* pos, PDLA_Indx* dims,              /* Move down one row */
                        int ndims );
void pdl_subsection( char *y, char*x, int datatype,      /* Take subsection */
                 PDLA_Indx* sec, PDLA_Indx* dims, PDLA_Indx *incs, PDLA_Indx offset, int* ndims);
void pdl_insertin( char*y, PDLA_Indx* ydims, int nydims,        /* Insert pdl in pdl */
                   char*x, PDLA_Indx* xdims, int nxdims,
                   int datatype, PDLA_Indx* pos);
PDLA_Anyval pdl_at( void* x, int datatype, PDLA_Indx* pos, PDLA_Indx* dims, /* Value at x,y,z,... */
             PDLA_Indx *incs, PDLA_Indx offset, int ndims);
void  pdl_set( void* x, int datatype, PDLA_Indx* pos, PDLA_Indx* dims, /* Set value at x,y,z... */
                PDLA_Indx *incs, PDLA_Indx offs, int ndims, PDLA_Anyval value);
void pdl_axisvals( pdl* a, int axis );               /* Fill with axis values */

/* Structure to hold pointers core PDLA routines so as to be used by many modules */

struct Core {
    I32    Version;
    pdl*   (*SvPDLAV)      ( SV*  );
    void   (*SetSV_PDLA)   ( SV *sv, pdl *it );
#if defined(PDLA_clean_namespace) || defined(PDLA_OLD_API)
    pdl*   (*new)      ( );     /* make it work with gimp-perl */
#else
    pdl*   (*pdlnew)      ( );  /* renamed because of C++ clash */
#endif
    pdl*   (*tmp)         ( );
    pdl*   (*create)      (int type);
    void   (*destroy)     (pdl *it);
    pdl*   (*null)        ();
    SV*    (*copy)        ( pdl*, char* );
    pdl*   (*hard_copy)   ( pdl* );
    void   (*converttype) ( pdl**, int, Logical );
    void** (*twod)        ( pdl* );
    void*  (*smalloc)      ( STRLEN );
    int    (*howbig)      ( int );
    PDLA_Indx*   (*packdims)    ( SV* sv, int *ndims ); /* Pack dims[] into SV aref */
    void   (*setdims)     ( pdl* it, PDLA_Indx* dims, int ndims );
    void   (*unpackdims)  ( SV* sv, PDLA_Indx *dims,    /* Unpack */
                            int ndims );
    void   (*grow)        ( pdl* a, PDLA_Indx newsize); /* Change pdl 'Data' size */
    void (*flushcache)( pdl *thepdl );	     /* flush cache */
    void (*reallocdims) ( pdl *it,int ndims );  /* reallocate dims and incs */
    void (*reallocthreadids) ( pdl *it,int ndims );
    void (*resize_defaultincs) ( pdl *it );     /* Make incs out of dims */

void (*thread_copy)(pdl_thread *from,pdl_thread *to);
void (*clearthreadstruct)(pdl_thread *it);
void (*initthreadstruct)(int nobl,pdl **pdls,PDLA_Indx *realdims,PDLA_Indx *creating,int npdls,
	pdl_errorinfo *info,pdl_thread *thread,char *flags, int noPthreadFlag );
int (*startthreadloop)(pdl_thread *thread,void (*func)(pdl_trans *),pdl_trans *);
PDLA_Indx *(*get_threadoffsp)(pdl_thread *thread); /* For pthreading */
int (*iterthreadloop)(pdl_thread *thread,int which);
void (*freethreadloop)(pdl_thread *thread);
void (*thread_create_parameter)(pdl_thread *thread,int j,PDLA_Indx *dims,
				int temp);
void (*add_deletedata_magic) (pdl *it,void (*func)(pdl *, Size_t param), Size_t param); /* Automagic destructor */
                             /* This needs to be fixed to work correctly for File::Map implementation */

/* XXX NOT YET IMPLEMENTED */
void (*setdims_careful)(pdl *pdl);
void (*put_offs)(pdl *pdl,PDLA_Indx offs, PDLA_Anyval val);
PDLA_Anyval (*get_offs)(pdl *pdl,PDLA_Indx offs);
PDLA_Anyval (*get)(pdl *pdl,PDLA_Indx *inds);
void (*set_trans_childtrans)(pdl *it, pdl_trans *trans,int nth);
void (*set_trans_parenttrans)(pdl *it, pdl_trans *trans,int nth);
pdl *(*make_now)(pdl *it);

pdl *(*get_convertedpdl)(pdl *pdl,int type);

void (*make_trans_mutual)(pdl_trans *trans);

/* Affine trans. THESE ARE SET IN ONE OF THE OTHER Basic MODULES
   and not in Core.xs ! */
void (*readdata_affine)(pdl_trans *tr);
void (*writebackdata_affine)(pdl_trans *tr);
void (*affine_new)(pdl *par,pdl *child,PDLA_Indx offs,SV *dims,SV *incs);

/* Converttype. Similar */
void (*converttypei_new)(pdl *par,pdl *child,int type);

void (*trans_mallocfreeproc)(struct pdl_trans *tr);

void (*make_physical)(pdl *it);
void (*make_physdims)(pdl *it);
void (*pdl_barf) (const char* pat,...);
void (*pdl_warn) (const char* pat,...);

void (*make_physvaffine)(pdl *it);
void (*allocdata) (pdl *it);
PDLA_Indx (*safe_indterm)(PDLA_Indx dsz, PDLA_Indx at, char *file, int lineno);

float NaN_float;
double NaN_double;

!NO!SUBS!

# set up the qsort routines

    # fortunately it looks like Types.pm.PL is processed before this
    # file
    require "./Types.pm";  # ie PDLA::Types

for (PDLA::Types::typesrtkeys()) {
   my $ctype = $PDLA::Types::typehash{$_}{ctype};
   my $ppsym = $PDLA::Types::typehash{$_}{ppsym};

   print OUT "void (*qsort_${ppsym}) (${ctype} *xx, PDLA_Indx a, PDLA_Indx b );\n";
   print OUT "void (*qsort_ind_${ppsym}) (${ctype} *xx, PDLA_Indx *ix, PDLA_Indx a, PDLA_Indx b );\n";
}

# storage space for bad values

print OUT <<'!NO!SUBS!';

  badvals bvals;  /* store the default bad values */
  void (*propagate_badflag) (pdl *it, int newval );  /* defined in bad.pd */
  void (*propagate_badvalue) (pdl *it);
  void (*children_changesoon)(pdl *it, int what);
  void (*changed)(pdl *it, int what, int recursing);
  void (*vaffinechanged)(pdl *it, int what);
  PDLA_Anyval (*get_pdl_badvalue)(pdl *it);
};

typedef struct Core Core;

Core *pdl__Core_get_Core(); /* INTERNAL TO CORE! DON'T CALL FROM OUTSIDE */

/* __PDLACORE_H */
#endif

!NO!SUBS!

