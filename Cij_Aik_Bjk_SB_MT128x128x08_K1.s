// sgemm NT (fast)

// Prefetch:   line 596
// Loop Begin: line 642
// Loop End:   line 787

.hsa_code_object_version 2,0
.hsa_code_object_isa 9, 0, 0, "AMD", "AMDGPU" 
.text
.p2align 8
.amdgpu_hsa_kernel Cij_Aik_Bjk_SB_MT128x128x08_K1Cij_Aik_Bjk_SB_MT128x128x08_K1
.amd_kernel_code_t
  is_ptr64 = 1
  enable_sgpr_kernarg_segment_ptr = 1
  kernarg_segment_byte_size = 68 // bytes of kern args
  workitem_vgpr_count = 128 // vgprs
  wavefront_sgpr_count = 40 // sgprs
  compute_pgm_rsrc1_vgprs = 31 // floor((128-1)/4)
  compute_pgm_rsrc1_sgprs = 5 // floor((40-1)/8)
  compute_pgm_rsrc2_tidig_comp_cnt = 0 // 1D wg
  compute_pgm_rsrc2_tgid_x_en = 1 // wg.x
  compute_pgm_rsrc2_tgid_y_en = 1 // wg.y
  compute_pgm_rsrc2_lds_size = 1 // ?
  workgroup_group_segment_byte_size = 16384 // lds bytes
  compute_pgm_rsrc2_user_sgpr = 2 // vcc
  kernarg_segment_alignment = 4
  group_segment_alignment = 4
  private_segment_alignment = 4
.end_amd_kernel_code_t

/******************************************/
/* VGPR Assignments                       */
/******************************************/
.set vgprValuC, 0
.set vgprValuA, 64
.set vgprValuBlkA, 72
.set vgprG2LA, 80
.set vgprValuB, 84
.set vgprValuBlkB, 92
.set vgprG2LB, 100
.set vgprLocalReadAddrA, 104
.set vgprLocalReadAddrB, 105
.set vgprLocalWriteAddrA, 106
.set vgprLocalWriteAddrB, 107
.set vgprGlobalReadAddrA, 108
.set vgprGlobalReadAddrB, 110
.set vgprGlobalReadIncsA, 112
.set vgprGlobalReadIncsB, 114
.set vgprSerial, 127

/******************************************/
/* SGPR Assignments                       */
/******************************************/
.set sgprKernArgAddress, 0
.set sgprWorkGroup0, 2
.set sgprWorkGroup1, 3
.set sgprNumWorkGroups0, 5
.set sgprNumWorkGroups1, 6
.set sgprAddressC, 7
.set sgprStridesC, 9
.set sgprAlpha, 10
.set sgprBeta, 11
.set sgprSizesFree, 12
.set sgprSizesSum, 14
.set sgprLoopPadding, 15
.set sgprStridesA, 25
.set sgprStridesB, 26
.set sgprAddressA, 27
.set sgprAddressB, 29
.set sgprOffsetC, 31
.set sgprOffsetA, 32
.set sgprOffsetB, 33
.set sgprLoopCounters, 15

/* Global Offset C */
.macro GLOBAL_OFFSET_C vgprAddr vgprOffset0I vgprOffset1J vgprTmp
v_mov_b32 v[\vgprAddr+0], v[\vgprOffset0I]         // d0 lower
v_mov_b32 v[\vgprAddr+1], 0x0                      // d0 upper
v_mul_lo_u32 v[\vgprTmp+0], s[sgprStridesC+0], v[\vgprOffset1J] // mul d1 lower
v_mul_hi_u32 v[\vgprTmp+1], s[sgprStridesC+0], v[\vgprOffset1J] // mul d1 upper
//v_add_u32 v[\vgprAddr+0], vcc, v[\vgprTmp+0], v[\vgprAddr+0] // accumulate d1 lower
//v_addc_u32 v[\vgprAddr+1], vcc, v[\vgprTmp+1], v[\vgprAddr+1], vcc // accumulate d1 upper
v_lshlrev_b64 v[\vgprAddr+0:\vgprAddr+1], 0x2, v[\vgprAddr+0:\vgprAddr+1] // offset *= bytes/element
.endm

/* Global Offset A */
.macro GLOBAL_OFFSET_A vgprAddr vgprOffset0I vgprOffsetK vgprTmp
v_mov_b32 v[\vgprAddr+0], v[\vgprOffset0I]         // d0 lower
v_mov_b32 v[\vgprAddr+1], 0x0                      // d0 upper
v_mul_lo_u32 v[\vgprTmp+0], s[sgprStridesA+0], v[\vgprOffsetK] // mul d1 lower
v_mul_hi_u32 v[\vgprTmp+1], s[sgprStridesA+0], v[\vgprOffsetK] // mul d1 upper
//v_add_u32 v[\vgprAddr+0], vcc, v[\vgprTmp+0], v[\vgprAddr+0] // accumulate d1 lower
//v_addc_u32 v[\vgprAddr+1], vcc, v[\vgprTmp+1], v[\vgprAddr+1], vcc // accumulate d1 upper
v_lshlrev_b64 v[\vgprAddr+0:\vgprAddr+1], 0x2, v[\vgprAddr+0:\vgprAddr+1] // offset *= bytes/element
.endm

/* Global Offset B */
.macro GLOBAL_OFFSET_B vgprAddr vgprOffset1J vgprOffsetK vgprTmp
v_mov_b32 v[\vgprAddr+0], v[\vgprOffset1J]         // d0 lower
v_mov_b32 v[\vgprAddr+1], 0x0                      // d0 upper
v_mul_lo_u32 v[\vgprTmp+0], s[sgprStridesB+0], v[\vgprOffsetK] // mul d1 lower
v_mul_hi_u32 v[\vgprTmp+1], s[sgprStridesB+0], v[\vgprOffsetK] // mul d1 upper
//v_add_u32 v[\vgprAddr+0], vcc, v[\vgprTmp+0], v[\vgprAddr+0] // accumulate d1 lower
//v_addc_u32 v[\vgprAddr+1], vcc, v[\vgprTmp+1], v[\vgprAddr+1], vcc // accumulate d1 upper
v_lshlrev_b64 v[\vgprAddr+0:\vgprAddr+1], 0x2, v[\vgprAddr+0:\vgprAddr+1] // offset *= bytes/element
.endm

/******************************************/
/* Dynamic Scalar Divide: vQuotient=vDividend/vDivisor; vRemainder=vDividend%vDivisor; */
/******************************************/
.macro DYNAMIC_VECTOR_DIVIDE vQuotient vRemainder vDividend vDivisor vTmp0 vTmp1 sTmp
v_cvt_f32_u32 v[\vQuotient], v[\vDivisor]          // 
v_rcp_f32 v[\vQuotient], v[\vQuotient]             // 
v_mul_f32 v[\vQuotient], 0x4f800000, v[\vQuotient] // 
v_cvt_u32_f32 v[\vQuotient], v[\vQuotient]         // 
v_mul_lo_u32 v[\vRemainder], v[\vDivisor], v[\vQuotient] // 
v_mul_hi_u32 v[\vTmp0], v[\vDivisor], v[\vQuotient] // 
//v_sub_u32 v[\vTmp1], vcc, 0x0, v[\vRemainder]      // 
v_cmp_ne_i32 s[\sTmp:\sTmp+1], 0x0, v[\vTmp0]      // 
v_cndmask_b32 v[\vRemainder], v[\vTmp1], v[\vRemainder], s[\sTmp:\sTmp+1] // 
v_mul_hi_u32 v[\vRemainder], v[\vRemainder], v[\vQuotient] // 
//v_sub_u32 v[\vTmp0], vcc, v[\vQuotient], v[\vRemainder] // 
//v_add_u32 v[\vQuotient], vcc, v[\vQuotient], v[\vRemainder] // 
v_cndmask_b32 v[\vQuotient], v[\vQuotient], v[\vTmp0], s[\sTmp:\sTmp+1] // 
v_mul_hi_u32 v[\vQuotient], v[\vQuotient], v[\vDividend] // 
v_mul_lo_u32 v[\vRemainder], v[\vQuotient], v[\vDivisor] // 
//v_sub_u32 v[\vTmp0], vcc, v[\vDividend], v[\vRemainder] // 
v_cmp_ge_u32 s[\sTmp:\sTmp+1], v[\vDividend], v[\vRemainder] // 
//v_add_u32 v[\vRemainder], vcc, 0x1, v[\vQuotient]  // 
//v_add_u32 v[\vTmp1], vcc, -1, v[\vQuotient]        // 
v_cmp_le_u32 vcc, v[\vDivisor], v[\vTmp0]          // 
s_and_b64 vcc, s[\sTmp:\sTmp+1], vcc               // 
v_cndmask_b32 v[\vQuotient], v[\vQuotient], v[\vRemainder], vcc // 
v_cndmask_b32 v[\vQuotient], v[\vTmp1], v[\vQuotient], s[\sTmp:\sTmp+1] // 
v_cmp_ne_i32 vcc, 0x0, v[\vDivisor]                // 
v_cndmask_b32 v[\vQuotient], -1, v[\vQuotient], vcc // final result
v_mul_lo_u32 v[\vRemainder], v[\vQuotient], v[\vDivisor] // 
//v_sub_u32 v[\vRemainder], vcc, v[\vDividend], v[\vRemainder] // final result
.endm

/******************************************/
/* 8x8 thread-tile                        */
/******************************************/
.macro MAC_8x8
v_mac_f32 v[vgprValuC+0+0*8], v[vgprValuA+0], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+1+0*8], v[vgprValuA+1], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+2+0*8], v[vgprValuA+2], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+3+0*8], v[vgprValuA+3], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+4+0*8], v[vgprValuA+4], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+5+0*8], v[vgprValuA+5], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+6+0*8], v[vgprValuA+6], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+7+0*8], v[vgprValuA+7], v[vgprValuB+0]
v_mac_f32 v[vgprValuC+0+1*8], v[vgprValuA+0], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+1+1*8], v[vgprValuA+1], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+2+1*8], v[vgprValuA+2], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+3+1*8], v[vgprValuA+3], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+4+1*8], v[vgprValuA+4], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+5+1*8], v[vgprValuA+5], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+6+1*8], v[vgprValuA+6], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+7+1*8], v[vgprValuA+7], v[vgprValuB+1]
v_mac_f32 v[vgprValuC+0+2*8], v[vgprValuA+0], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+1+2*8], v[vgprValuA+1], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+2+2*8], v[vgprValuA+2], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+3+2*8], v[vgprValuA+3], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+4+2*8], v[vgprValuA+4], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+5+2*8], v[vgprValuA+5], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+6+2*8], v[vgprValuA+6], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+7+2*8], v[vgprValuA+7], v[vgprValuB+2]
v_mac_f32 v[vgprValuC+0+3*8], v[vgprValuA+0], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+1+3*8], v[vgprValuA+1], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+2+3*8], v[vgprValuA+2], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+3+3*8], v[vgprValuA+3], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+4+3*8], v[vgprValuA+4], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+5+3*8], v[vgprValuA+5], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+6+3*8], v[vgprValuA+6], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+7+3*8], v[vgprValuA+7], v[vgprValuB+3]
v_mac_f32 v[vgprValuC+0+4*8], v[vgprValuA+0], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+1+4*8], v[vgprValuA+1], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+2+4*8], v[vgprValuA+2], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+3+4*8], v[vgprValuA+3], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+4+4*8], v[vgprValuA+4], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+5+4*8], v[vgprValuA+5], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+6+4*8], v[vgprValuA+6], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+7+4*8], v[vgprValuA+7], v[vgprValuB+4]
v_mac_f32 v[vgprValuC+0+5*8], v[vgprValuA+0], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+1+5*8], v[vgprValuA+1], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+2+5*8], v[vgprValuA+2], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+3+5*8], v[vgprValuA+3], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+4+5*8], v[vgprValuA+4], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+5+5*8], v[vgprValuA+5], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+6+5*8], v[vgprValuA+6], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+7+5*8], v[vgprValuA+7], v[vgprValuB+5]
v_mac_f32 v[vgprValuC+0+6*8], v[vgprValuA+0], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+1+6*8], v[vgprValuA+1], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+2+6*8], v[vgprValuA+2], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+3+6*8], v[vgprValuA+3], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+4+6*8], v[vgprValuA+4], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+5+6*8], v[vgprValuA+5], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+6+6*8], v[vgprValuA+6], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+7+6*8], v[vgprValuA+7], v[vgprValuB+6]
v_mac_f32 v[vgprValuC+0+7*8], v[vgprValuA+0], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+1+7*8], v[vgprValuA+1], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+2+7*8], v[vgprValuA+2], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+3+7*8], v[vgprValuA+3], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+4+7*8], v[vgprValuA+4], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+5+7*8], v[vgprValuA+5], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+6+7*8], v[vgprValuA+6], v[vgprValuB+7]
v_mac_f32 v[vgprValuC+7+7*8], v[vgprValuA+7], v[vgprValuB+7]
.endm
.macro MAC_8x8_BLK
v_mac_f32 v[vgprValuC+0+0*8], v[vgprValuBlkA+0], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+1+0*8], v[vgprValuBlkA+1], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+2+0*8], v[vgprValuBlkA+2], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+3+0*8], v[vgprValuBlkA+3], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+4+0*8], v[vgprValuBlkA+4], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+5+0*8], v[vgprValuBlkA+5], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+6+0*8], v[vgprValuBlkA+6], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+7+0*8], v[vgprValuBlkA+7], v[vgprValuBlkB+0]
v_mac_f32 v[vgprValuC+0+1*8], v[vgprValuBlkA+0], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+1+1*8], v[vgprValuBlkA+1], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+2+1*8], v[vgprValuBlkA+2], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+3+1*8], v[vgprValuBlkA+3], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+4+1*8], v[vgprValuBlkA+4], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+5+1*8], v[vgprValuBlkA+5], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+6+1*8], v[vgprValuBlkA+6], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+7+1*8], v[vgprValuBlkA+7], v[vgprValuBlkB+1]
v_mac_f32 v[vgprValuC+0+2*8], v[vgprValuBlkA+0], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+1+2*8], v[vgprValuBlkA+1], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+2+2*8], v[vgprValuBlkA+2], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+3+2*8], v[vgprValuBlkA+3], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+4+2*8], v[vgprValuBlkA+4], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+5+2*8], v[vgprValuBlkA+5], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+6+2*8], v[vgprValuBlkA+6], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+7+2*8], v[vgprValuBlkA+7], v[vgprValuBlkB+2]
v_mac_f32 v[vgprValuC+0+3*8], v[vgprValuBlkA+0], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+1+3*8], v[vgprValuBlkA+1], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+2+3*8], v[vgprValuBlkA+2], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+3+3*8], v[vgprValuBlkA+3], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+4+3*8], v[vgprValuBlkA+4], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+5+3*8], v[vgprValuBlkA+5], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+6+3*8], v[vgprValuBlkA+6], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+7+3*8], v[vgprValuBlkA+7], v[vgprValuBlkB+3]
v_mac_f32 v[vgprValuC+0+4*8], v[vgprValuBlkA+0], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+1+4*8], v[vgprValuBlkA+1], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+2+4*8], v[vgprValuBlkA+2], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+3+4*8], v[vgprValuBlkA+3], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+4+4*8], v[vgprValuBlkA+4], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+5+4*8], v[vgprValuBlkA+5], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+6+4*8], v[vgprValuBlkA+6], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+7+4*8], v[vgprValuBlkA+7], v[vgprValuBlkB+4]
v_mac_f32 v[vgprValuC+0+5*8], v[vgprValuBlkA+0], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+1+5*8], v[vgprValuBlkA+1], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+2+5*8], v[vgprValuBlkA+2], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+3+5*8], v[vgprValuBlkA+3], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+4+5*8], v[vgprValuBlkA+4], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+5+5*8], v[vgprValuBlkA+5], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+6+5*8], v[vgprValuBlkA+6], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+7+5*8], v[vgprValuBlkA+7], v[vgprValuBlkB+5]
v_mac_f32 v[vgprValuC+0+6*8], v[vgprValuBlkA+0], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+1+6*8], v[vgprValuBlkA+1], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+2+6*8], v[vgprValuBlkA+2], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+3+6*8], v[vgprValuBlkA+3], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+4+6*8], v[vgprValuBlkA+4], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+5+6*8], v[vgprValuBlkA+5], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+6+6*8], v[vgprValuBlkA+6], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+7+6*8], v[vgprValuBlkA+7], v[vgprValuBlkB+6]
v_mac_f32 v[vgprValuC+0+7*8], v[vgprValuBlkA+0], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+1+7*8], v[vgprValuBlkA+1], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+2+7*8], v[vgprValuBlkA+2], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+3+7*8], v[vgprValuBlkA+3], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+4+7*8], v[vgprValuBlkA+4], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+5+7*8], v[vgprValuBlkA+5], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+6+7*8], v[vgprValuBlkA+6], v[vgprValuBlkB+7]
v_mac_f32 v[vgprValuC+7+7*8], v[vgprValuBlkA+7], v[vgprValuBlkB+7]
.endm

/******************************************/
/* Allocate Resources                     */
/******************************************/
s_mov_b32 m0, 0x4000                               // LDS clamp at 16384 bytes
v_mov_b32 v[vgprSerial], v0                        // thread serial id

/* Load Kernel Args */
s_load_dword s[sgprAddressC], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x0 // load addr c
s_load_dword s[sgprAddressC+1], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x4 // load addr c
s_load_dword s[sgprAddressA], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x8 // load addr a
s_load_dword s[sgprAddressA+1], s[sgprKernArgAddress:sgprKernArgAddress+1], 0xc // load addr a
s_load_dword s[sgprAddressB], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x10 // load addr b
s_load_dword s[sgprAddressB+1], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x14 // load addr b
s_load_dword s[sgprAlpha], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x18 // load alpha
s_load_dword s[sgprBeta], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x1c // load beta
s_load_dword s[sgprOffsetC], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x20 // load offset c
s_load_dword s[sgprOffsetA], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x24 // load offset a
s_load_dword s[sgprOffsetB], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x28 // load offset b
s_load_dword s[sgprStridesC+0], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x2c // load stride c 0
s_load_dword s[sgprStridesA+0], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x30 // load stride a 0
s_load_dword s[sgprStridesB+0], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x34 // load stride b 0
s_load_dword s[sgprSizesFree+0], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x38 // load size free 0
s_load_dword s[sgprSizesFree+1], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x3c // load size free 1
s_load_dword s[sgprSizesSum+0], s[sgprKernArgAddress:sgprKernArgAddress+1], 0x40 // load size free 0
s_waitcnt lgkmcnt(0)                               // wait for 68 bytes of kern args

/* User Offsets */
s_add_u32 s[sgprAddressC], s[sgprOffsetC], s[sgprAddressC] // addrC += offsetC
s_mov_b32 s[sgprOffsetC], 0                        // 
s_addc_u32 s[sgprAddressC], s[sgprOffsetC], s[sgprAddressC] // addrC += offsetC carry
s_add_u32 s[sgprAddressA], s[sgprOffsetA], s[sgprAddressA] // addrA += offsetA
s_mov_b32 s[sgprOffsetA], 0                        // 
s_addc_u32 s[sgprAddressA], s[sgprOffsetA], s[sgprAddressA] // addrA += offsetA carry
s_add_u32 s[sgprAddressB], s[sgprOffsetB], s[sgprAddressB] // addrB += offsetB
s_mov_b32 s[sgprOffsetB], 0                        // 
s_addc_u32 s[sgprAddressB], s[sgprOffsetB], s[sgprAddressB] // addrB += offsetB carry
// size0 = (size0I + MT0I - 1) / MT0I;
v_mov_b32 v0, s[sgprSizesFree+0]                   // 
s_mov_b32 s31, 0x7f                                // 
//v_add_u32 v0, vcc, s31, v0                         // v0 = size0+MT0-1
v_lshrrev_b32 v3, 7, v0                            // v3 = v0 / 128
v_readfirstlane_b32 s[sgprNumWorkGroups0], v3      // 
// size1 = (size1J + MT1J - 1) / MT1J;
v_mov_b32 v0, s[sgprSizesFree+1]                   // 
s_mov_b32 s31, 0x7f                                // 
//v_add_u32 v0, vcc, s31, v0                         // v0 = size1+MT1-1
v_lshrrev_b32 v3, 7, v0                            // v3 = v0 / 128
v_readfirstlane_b32 s[sgprNumWorkGroups1], v3      // 

/******************************************/
/* Global Read Addresses                  */
/******************************************/

/* global read addresses: subgroup */
/*   not needed until local read addresses */

/* global read addresses: work-group */
// nwg0 = (size0I + MT0I - 1) / MT0I;
v_mov_b32 v2, s[sgprSizesFree+0]                   // 
s_mov_b32 s32, 0x7f                                // 
//v_add_u32 v2, vcc, s32, v2                         // v2 = size0+MT0-1
v_lshrrev_b32 v2, 7, v2                            // v2 = v2 / 128
// nwg1 = (size1J + MT1J - 1) / MT1J;
v_mov_b32 v3, s[sgprSizesFree+1]                   // 
s_mov_b32 s32, 0x7f                                // 
//v_add_u32 v3, vcc, s32, v3                         // v3 = size1+MT1-1
v_lshrrev_b32 v3, 7, v3                            // v3 = v3 / 128
v_mov_b32 v6, s[sgprWorkGroup1]                    // wg1
v_lshrrev_b32 v4, 3, v6                            // v4 = v6 / 8
v_and_b32 v5, 7, v6                                // v5 = v6 % 8
v_mul_lo_u32 v5, v5, v2                            // (wg1 % WGM)*nwg0
//v_add_u32 v5, vcc, s[sgprWorkGroup0], v5           // wgSerial = wg0 + (wg1 % WGM)*nwg0
// numFullBlocks = (nwg1) / WGM
v_lshrrev_b32 v2, 3, v3                            // v2 = v3 / 8
v_and_b32 v7, 7, v3                                // v7 = v3 % 8
v_cmp_lt_u32 s[32:33], v4, v2                      // blockId < numFullBlocks
v_cndmask_b32 v2, v7, 0x8, s[32:33]                // blockWidth = (blockId < numFullBlocks) ? WGM : remainder
DYNAMIC_VECTOR_DIVIDE 3 6 5 2 0 1 32
v_mul_lo_u32 v4, v4, 8                             // blockId * WGM
//v_add_u32 v6, vcc, v6, v4                          // wg1 += blockId * WGM
v_readfirstlane_b32 s[sgprWorkGroup0], v3          // 
v_readfirstlane_b32 s[sgprWorkGroup1], v6          // 

/* global read addresses: tile offset assignment a */
/* v2 = groA-tile = serial%LVCA + (wgA*MTA) */
/* v1 = groA-unroll = serial/LVCA */
v_lshrrev_b32 v1, 5, v[vgprSerial]                 // v1 = v[vgprSerial] / 32
v_and_b32 v0, 31, v[vgprSerial]                    // v0 = v[vgprSerial] % 32
v_lshlrev_b32 v0, 2, v0                            // v0 = v0 * 4
v_lshlrev_b32 v3, 7, s[sgprWorkGroup0]             // v3 = s[sgprWorkGroup0] * 128
//v_add_u32 v2, vcc, v3, v0                          // groA-tile = serial%LVCA*VW + (wgA*MTA)

/* global read addresses: tile offset assignment b */
/* v5 = groB-tile = serial%LVCB + (wgB*MTB) */
/* v4 = groB-unroll = serial/LVCB */
v_lshrrev_b32 v4, 5, v[vgprSerial]                 // v4 = v[vgprSerial] / 32
v_and_b32 v3, 31, v[vgprSerial]                    // v3 = v[vgprSerial] % 32
v_lshlrev_b32 v3, 2, v3                            // v3 = v3 * 4
v_lshlrev_b32 v6, 7, s[sgprWorkGroup1]             // v6 = s[sgprWorkGroup1] * 128
//v_add_u32 v5, vcc, v6, v3                          // groB-tile = serial%LVCB*VW + (wgB*MTB)

/* global read addresses: unroll assignment a */
/* v1 */

/* global read addresses: unroll assignment b */
/* v4 */

/* global read addresses: tile offsets a */
v_mov_b32 v6, v2                                   // groA0I_0

/* global read addresses: tile offsets b */
v_mov_b32 v2, v5                                   // groB1J_0

/* global read addresses: unroll offsets a */
v_mov_b32 v5, v1                                   // groAK_0

/* global read addresses: unroll offsets b */
v_mov_b32 v7, v4                                   // groBK_0

/* global read addresses: shift a */
s_add_u32 s31, -0x4, s[sgprSizesFree+0]            // edge = Size0I-4
v_mov_b32 v8, s31                                  // edge = Size0I-4
v_cmp_lt_u32 s[32:33], v6, v8                      // offset < edge
v_cndmask_b32 v6, v8, v6, s[32:33]                 // offset = (offset < edge) ? offset : edge

/* global read addresses: shift b */
s_add_u32 s31, -0x4, s[sgprSizesFree+1]            // edge = Size1J-4
v_mov_b32 v8, s31                                  // edge = Size1J-4
v_cmp_lt_u32 s[32:33], v2, v8                      // offset < edge
v_cndmask_b32 v2, v8, v2, s[32:33]                 // offset = (offset < edge) ? offset : edge

/* global read addresses: final offsets a */
GLOBAL_OFFSET_A vgprGlobalReadAddrA+0,  6,  5, 8 // gROA_0_0_0_0

/* global read addresses: final offsets b */
GLOBAL_OFFSET_B vgprGlobalReadAddrB+0,  2,  7, 8 // gROB_0_0_0_0

/* global read addresses: apply user offsets */
/* moved earlier */

/* global read addresses: addresses a */
v_mov_b32 v5, s[sgprAddressA+0]                    // 
v_mov_b32 v6, s[sgprAddressA+1]                    // 
//v_add_u32 v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v5 // gRAA_0_0_0_0 = addrA+grOA_0_0_0_0 (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v6, vcc // gRAA_0_0_0_0 = addrA+grOA_0_0_0_0 (upper)

/* global read addresses: addresses b */
v_mov_b32 v5, s[sgprAddressB+0]                    // 
v_mov_b32 v6, s[sgprAddressB+1]                    // 
//v_add_u32 v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v5 // gRAB_0_0_0_0 = addrB+grOB_0_0_0_0 (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v6, vcc // gRAB_0_0_0_0 = addrB+grOB_0_0_0_0 (upper)

/* global read addresses: increments a */
s_mul_i32 s31, 0x20, s[sgprStridesA]               // incr = stride*8*bytes
s_mov_b32 s32, 0x0                                 // (carry)
v_mov_b32 v[vgprGlobalReadIncsA+0], s31            // 
v_mov_b32 v[vgprGlobalReadIncsA+1], s32            // 

/* global read addresses: increments b */
s_mul_i32 s31, 0x20, s[sgprStridesB]               // incr = stride*8*bytes
s_mov_b32 s32, 0x0                                 // (carry)
v_mov_b32 v[vgprGlobalReadIncsB+0], s31            // 
v_mov_b32 v[vgprGlobalReadIncsB+1], s32            // 

/******************************************/
/* Local Write Addresses                  */
/******************************************/

/* local write addresses: tile assignment a */
/* lwaTileA = v0 */

/* local write addresses: tile assignment b */
/* lwaTileB = v3 */

/* local write addresses: unroll assignment a */
/* lwaUnrollA = v1 */

/* local write addresses: unroll assignment b */
/* lwaUnrollB = v4 */

/* local write addresses: first offset a */
v_mul_u32_u24 v[vgprLocalWriteAddrA], 0x80, v1     // lwAK*MTA
//v_add_u32 v[vgprLocalWriteAddrA], vcc, v0, v[vgprLocalWriteAddrA] // lwFOA = lwA0I + lwAK*MT0I
v_lshlrev_b32 v[vgprLocalWriteAddrA], 0x2, v[vgprLocalWriteAddrA] //  *= bytes/element

/* local write addresses: first offset b */
v_mul_u32_u24 v[vgprLocalWriteAddrB], 0x80, v4     // lwBK*MTB
//v_add_u32 v[vgprLocalWriteAddrB], vcc, v3, v[vgprLocalWriteAddrB] // lwFOB = lwB1J + lwBK*MT1J
v_lshlrev_b32 v[vgprLocalWriteAddrB], 0x2, v[vgprLocalWriteAddrB] //  *= bytes/element
//v_add_u32 v[vgprLocalWriteAddrB], vcc, 0x1000, v[vgprLocalWriteAddrB] // lwFOB = lwB1J + lwBK*MT1J + LDS_OFFSET_B=1024*4

/* local write addresses: final offsets a */

/* N/A */

/* local write addresses: final offsets b */

/* N/A */

/* local write addresses: declare addresses a */
/* N/A */

/* local write addresses: declare addresses b */
/* N/A */

/* local write addresses: init pointers a */
/* N/A */

/* local write addresses: init pointers b */
/* N/A */

/******************************************/
/* Local Read Addresses                   */
/******************************************/

/* local read addresses: tile assignments a */
/*lr0I = serial % SG0I*/
v_lshrrev_b32 v0, 4, v[vgprSerial]                 // v0 = v[vgprSerial] / 16
v_and_b32 v1, 15, v[vgprSerial]                    // v1 = v[vgprSerial] % 16

/* local read addresses: tile assignments b */
/*lr1J = (serial / SG1J) % SG1J*/
v_lshrrev_b32 v2, 4, v0                            // v2 = v0 / 16
v_and_b32 v3, 15, v0                               // v3 = v0 % 16

/* local read addresses: final offsets a */
v_lshrrev_b32 v0, 8, v[vgprSerial]                 // v0 = v[vgprSerial] / 256
v_and_b32 v2, 255, v[vgprSerial]                   // v2 = v[vgprSerial] % 256
s_mov_b32 s31, 0x80                                // MT0
v_mul_lo_u32 v0, s31, v0                           // sgid*sgid*MT0
v_lshlrev_b32 v1, 2, v1                            // v1 = v1 * 4
//v_add_u32 v[vgprLocalReadAddrA], vcc, v0, v1       // o = lroA*VW+sgid*MT0
v_lshlrev_b32 v[vgprLocalReadAddrA], 0x2, v[vgprLocalReadAddrA] // *= bytes/element

/* local read addresses: final offsets b */
v_lshrrev_b32 v0, 8, v[vgprSerial]                 // v0 = v[vgprSerial] / 256
v_and_b32 v1, 255, v[vgprSerial]                   // v1 = v[vgprSerial] % 256
s_mov_b32 s31, 0x80                                // MT1
v_mul_lo_u32 v0, s31, v0                           // sgid*sgid*MT1
v_lshlrev_b32 v3, 2, v3                            // v3 = v3 * 4
//v_add_u32 v[vgprLocalReadAddrB], vcc, v0, v3       // o = lroB*VW+sgid*MT1
v_lshlrev_b32 v[vgprLocalReadAddrB], 0x2, v[vgprLocalReadAddrB] // *= bytes/element

/* local read addresses: declare addresses a */
/* N/A */

/* local read addresses: declare addresses b */
//v_add_u32 v[vgprLocalReadAddrB+0], vcc, 0x1000, v[vgprLocalReadAddrB+0] //  += LdsOffsetB (lower)

/* declare loop num iterations */
v_mov_b32 v[vgprValuC+0], 0x0                      // 
v_mov_b32 v[vgprValuC+1], 0x0                      // 
v_mov_b32 v[vgprValuC+2], 0x0                      // 
v_mov_b32 v[vgprValuC+3], 0x0                      // 
v_mov_b32 v[vgprValuC+4], 0x0                      // 
v_mov_b32 v[vgprValuC+5], 0x0                      // 
v_mov_b32 v[vgprValuC+6], 0x0                      // 
v_mov_b32 v[vgprValuC+7], 0x0                      // 
v_mov_b32 v[vgprValuC+8], 0x0                      // 
v_mov_b32 v[vgprValuC+9], 0x0                      // 
v_mov_b32 v[vgprValuC+10], 0x0                     // 
v_mov_b32 v[vgprValuC+11], 0x0                     // 
v_mov_b32 v[vgprValuC+12], 0x0                     // 
v_mov_b32 v[vgprValuC+13], 0x0                     // 
v_mov_b32 v[vgprValuC+14], 0x0                     // 
v_mov_b32 v[vgprValuC+15], 0x0                     // 
v_mov_b32 v[vgprValuC+16], 0x0                     // 
v_mov_b32 v[vgprValuC+17], 0x0                     // 
v_mov_b32 v[vgprValuC+18], 0x0                     // 
v_mov_b32 v[vgprValuC+19], 0x0                     // 
v_mov_b32 v[vgprValuC+20], 0x0                     // 
v_mov_b32 v[vgprValuC+21], 0x0                     // 
v_mov_b32 v[vgprValuC+22], 0x0                     // 
v_mov_b32 v[vgprValuC+23], 0x0                     // 
v_mov_b32 v[vgprValuC+24], 0x0                     // 
v_mov_b32 v[vgprValuC+25], 0x0                     // 
v_mov_b32 v[vgprValuC+26], 0x0                     // 
v_mov_b32 v[vgprValuC+27], 0x0                     // 
v_mov_b32 v[vgprValuC+28], 0x0                     // 
v_mov_b32 v[vgprValuC+29], 0x0                     // 
v_mov_b32 v[vgprValuC+30], 0x0                     // 
v_mov_b32 v[vgprValuC+31], 0x0                     // 
v_mov_b32 v[vgprValuC+32], 0x0                     // 
v_mov_b32 v[vgprValuC+33], 0x0                     // 
v_mov_b32 v[vgprValuC+34], 0x0                     // 
v_mov_b32 v[vgprValuC+35], 0x0                     // 
v_mov_b32 v[vgprValuC+36], 0x0                     // 
v_mov_b32 v[vgprValuC+37], 0x0                     // 
v_mov_b32 v[vgprValuC+38], 0x0                     // 
v_mov_b32 v[vgprValuC+39], 0x0                     // 
v_mov_b32 v[vgprValuC+40], 0x0                     // 
v_mov_b32 v[vgprValuC+41], 0x0                     // 
v_mov_b32 v[vgprValuC+42], 0x0                     // 
v_mov_b32 v[vgprValuC+43], 0x0                     // 
v_mov_b32 v[vgprValuC+44], 0x0                     // 
v_mov_b32 v[vgprValuC+45], 0x0                     // 
v_mov_b32 v[vgprValuC+46], 0x0                     // 
v_mov_b32 v[vgprValuC+47], 0x0                     // 
v_mov_b32 v[vgprValuC+48], 0x0                     // 
v_mov_b32 v[vgprValuC+49], 0x0                     // 
v_mov_b32 v[vgprValuC+50], 0x0                     // 
v_mov_b32 v[vgprValuC+51], 0x0                     // 
v_mov_b32 v[vgprValuC+52], 0x0                     // 
v_mov_b32 v[vgprValuC+53], 0x0                     // 
v_mov_b32 v[vgprValuC+54], 0x0                     // 
v_mov_b32 v[vgprValuC+55], 0x0                     // 
v_mov_b32 v[vgprValuC+56], 0x0                     // 
v_mov_b32 v[vgprValuC+57], 0x0                     // 
v_mov_b32 v[vgprValuC+58], 0x0                     // 
v_mov_b32 v[vgprValuC+59], 0x0                     // 
v_mov_b32 v[vgprValuC+60], 0x0                     // 
v_mov_b32 v[vgprValuC+61], 0x0                     // 
v_mov_b32 v[vgprValuC+62], 0x0                     // 
v_mov_b32 v[vgprValuC+63], 0x0                     // 
s_lshr_b32 s[sgprLoopCounters+0], s[sgprSizesSum+0], 3 // s[sgprLoopCounters+0] = s[sgprSizesSum+0] / 8
s_sub_u32 s[sgprLoopCounters+0], 0x0, s[sgprLoopCounters+0] // counterK = -sizeK

/******************************************/
/* Prefetch                               */
/******************************************/

/* prefetch: global -> local */
s_cmp_eq_u32 s[sgprLoopCounters+0], 0x0            // numIter0I == 0
s_cbranch_scc1 label_0003                          // skip to end of prefetch last iter b/c numIter==0

/* global read a */
flat_load_dwordx4 v[vgprG2LA+0:vgprG2LA+0+3], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // G -> Reg 0_0_0_0

/* global read b */
flat_load_dwordx4 v[vgprG2LB+0:vgprG2LB+0+3], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // G -> Reg 0_0_0_0

/* global read inc a */
//v_add_u32  v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v[vgprGlobalReadIncsA+0+0] // gra += incAK (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v[vgprGlobalReadIncsA+0+1], vcc // gra += incAK (upper)

/* global read inc b */
//v_add_u32  v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v[vgprGlobalReadIncsB+0+0] // gra += incBK (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v[vgprGlobalReadIncsB+0+1], vcc // gra += incBK (upper)
s_waitcnt vmcnt(0) // wait for global read

/* local write a */
ds_write_b128 v[vgprLocalWriteAddrA], v[vgprG2LA+0:vgprG2LA+0+3] offset:0 // lwoA_0_0_0_0 = (0*LSCA) + (0*LSPA)*MT0I = 0

/* local write b */
ds_write_b128 v[vgprLocalWriteAddrB], v[vgprG2LB+0:vgprG2LB+0+3] offset:0 // lwoB_0_0_0_0 = (0*LSCB) + (0*LSPB)*MT1J = 0

/* local write swap a */
v_xor_b32 v[vgprLocalWriteAddrA], 0x2000, v[vgprLocalWriteAddrA] // swap Red Blk

/* local write swap b */
v_xor_b32 v[vgprLocalWriteAddrB], 0x2000, v[vgprLocalWriteAddrB] // swap Red Blk

s_waitcnt lgkmcnt(0) // wait for local write
s_barrier

/* local read prefetch a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:256 // L -> Reg 0

/* local read prefetch b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:256 // L -> Reg 0

/******************************************/
/* Unrolled Loop - Begin                  */
/******************************************/
s_cmp_ge_i32 s[sgprLoopCounters+0], -0x1           // LoopCounterK < EndCounter
s_cbranch_scc1 label_0002                          // don't enter LoopK
label_0001:

/* global read a */
flat_load_dwordx4 v[vgprG2LA+0:vgprG2LA+0+3], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // G -> Reg 0_0_0_0

/* global read b */
flat_load_dwordx4 v[vgprG2LB+0:vgprG2LB+0+3], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // G -> Reg 0_0_0_0

/* global read inc a */
//v_add_u32  v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v[vgprGlobalReadIncsA+0+0] // gra += incAK (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v[vgprGlobalReadIncsA+0+1], vcc // gra += incAK (upper)

/* global read inc b */
//v_add_u32  v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v[vgprGlobalReadIncsB+0+0] // gra += incBK (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v[vgprGlobalReadIncsB+0+1], vcc // gra += incBK (upper)

/* iter 0 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:512 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:768 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:512 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:768 // L -> Reg 0

s_waitcnt lgkmcnt(6) // wait for prior local read
MAC_8x8

/* iter 1 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:1024 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:1280 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:1024 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:1280 // L -> Reg 0

s_waitcnt lgkmcnt(4) // wait for prior local read
MAC_8x8_BLK

/* iter 2 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:1536 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:1792 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:1536 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:1792 // L -> Reg 0

s_waitcnt lgkmcnt(4) // wait for prior local read
MAC_8x8

/* iter 3 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:2048 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:2304 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:2048 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:2304 // L -> Reg 0

s_waitcnt lgkmcnt(4) // wait for prior local read
MAC_8x8_BLK

/* iter 4 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:2560 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:2816 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:2560 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:2816 // L -> Reg 0

s_waitcnt lgkmcnt(4) // wait for prior local read
MAC_8x8

/* iter 5 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:3072 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:3328 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:3072 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:3328 // L -> Reg 0

s_waitcnt lgkmcnt(4) // wait for prior local read
MAC_8x8_BLK

/* iter 6 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:3584 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:3840 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:3584 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:3840 // L -> Reg 0
s_waitcnt vmcnt(0) // wait for global read

/* local write a */
ds_write_b128 v[vgprLocalWriteAddrA], v[vgprG2LA+0:vgprG2LA+0+3] offset:0 // lwoA_0_0_0_0 = (0*LSCA) + (0*LSPA)*MT0I = 0

/* local write b */
ds_write_b128 v[vgprLocalWriteAddrB], v[vgprG2LB+0:vgprG2LB+0+3] offset:0 // lwoB_0_0_0_0 = (0*LSCB) + (0*LSPB)*MT1J = 0

/* local write swap offsets a */
v_xor_b32 v[vgprLocalWriteAddrA], 0x2000, v[vgprLocalWriteAddrA] // swap Red Blk

/* local write swap offsets b */
v_xor_b32 v[vgprLocalWriteAddrB], 0x2000, v[vgprLocalWriteAddrB] // swap Red Blk

/* local read swap offsets a */
v_xor_b32 v[vgprLocalReadAddrA], 0x2000, v[vgprLocalReadAddrA] // swap Red Blk

/* local read swap offsets b */
v_xor_b32 v[vgprLocalReadAddrB], 0x2000, v[vgprLocalReadAddrB] // swap Red Blk

s_waitcnt lgkmcnt(6) // wait for prior local read
MAC_8x8

/* iter 7 */
s_waitcnt lgkmcnt(0) // wait for local write
s_barrier

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:256 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:256 // L -> Reg 0

MAC_8x8_BLK

/******************************************/
/* Unrolled Loop - End                    */
/******************************************/
s_add_u32 s[sgprLoopCounters+0], s[sgprLoopCounters+0], 0x1 // counterK++
s_cmp_eq_i32 s[sgprLoopCounters+0], -0x1           // counterK==0
s_cbranch_scc1 label_0002                          // exit LoopK
s_branch label_0001                                // restart LoopK
label_0002:

/* prefetch: last unrolled iteration */

/* iter 0 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:512 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:768 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:512 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:768 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8

/* iter 1 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:1024 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:1280 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:1024 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:1280 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8_BLK

/* iter 2 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:1536 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:1792 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:1536 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:1792 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8

/* iter 3 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:2048 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:2304 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:2048 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:2304 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8_BLK

/* iter 4 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:2560 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:2816 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:2560 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:2816 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8

/* iter 5 */

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:3072 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:3328 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:3072 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:3328 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8_BLK

/* iter 6 */

/* local read a */
ds_read_b128 v[vgprValuBlkA+0:vgprValuBlkA+0+3], v[vgprLocalReadAddrA] offset:3584 // L -> Reg 0
ds_read_b128 v[vgprValuBlkA+4:vgprValuBlkA+4+3], v[vgprLocalReadAddrA] offset:3840 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuBlkB+0:vgprValuBlkB+0+3], v[vgprLocalReadAddrB] offset:3584 // L -> Reg 0
ds_read_b128 v[vgprValuBlkB+4:vgprValuBlkB+4+3], v[vgprLocalReadAddrB] offset:3840 // L -> Reg 0

/* local read inc a */
/* N/A */

/* local read inc b */
/* N/A */
s_waitcnt lgkmcnt(4) // wait for local read
MAC_8x8

/* iter 7 */
s_waitcnt lgkmcnt(0) // wait for local read
MAC_8x8_BLK
label_0003:

/******************************************/
/* Tail Loop                              */
/******************************************/
//numIterK = (((sizeK % LOCAL_DEPTHU) + LOCAL_SPLITU - 1) / LOCAL_SPLITU)
s_lshr_b32 s32, s[sgprSizesSum+0], 3               // s32 = s[sgprSizesSum+0] / 8
s_and_b32 s[sgprLoopCounters+0], 7, s[sgprSizesSum+0] // s[sgprLoopCounters+0] = s[sgprSizesSum+0] % 8
s_cmp_eq_u32 s[sgprLoopCounters+0], 0x0            // numIterK == 0
s_cbranch_scc1 label_0005                          // skip to end of tail loop b/c numIter==0
s_sub_u32 s[sgprLoopCounters+0], 0x0, s[sgprLoopCounters+0] // counterK = -sizeK

/* global read a */
/* max read address = size[n] * stride[n-1] */
s_mul_i32 s32, s[sgprSizesSum+0], s[sgprStridesA+0] // mul d1 lower
s_mov_b32 s33, 0x0                                 // zero (upper)
s_lshl_b64 s[32:33], s[32:33], 0x2                 // offset *= bytes/element
s_add_u32 s32, s27, s32                            // prepend address lower
s_addc_u32 s33, s28, s33                           // prepend address upper
v_mov_b32 v116, s32                                // sgpr->vgpr
v_mov_b32 v117, s33                                // sgpr->vgpr
s_mov_b64 s[34:35], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
v_mov_b32 v118, 0x4                                // bytes per element
v_mov_b32 v119, 0x0                                // zero
/* load component 0 */
v_mov_b32 v[vgprG2LA+0+0], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LA+0+0], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v119, vcc // gra += 1 (upper)
/* load component 1 */
v_mov_b32 v[vgprG2LA+0+1], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LA+0+1], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v119, vcc // gra += 1 (upper)
/* load component 2 */
v_mov_b32 v[vgprG2LA+0+2], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LA+0+2], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v119, vcc // gra += 1 (upper)
/* load component 3 */
v_mov_b32 v[vgprG2LA+0+3], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LA+0+3], v[vgprGlobalReadAddrA+0:vgprGlobalReadAddrA+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrA+0+0], vcc, v[vgprGlobalReadAddrA+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrA+0+1], vcc, v[vgprGlobalReadAddrA+0+1], v119, vcc // gra += 1 (upper)

/* global read b */
/* max read address = size[n] * stride[n-1] */
s_mul_i32 s32, s[sgprSizesSum+0], s[sgprStridesB+0] // mul d1 lower
s_mov_b32 s33, 0x0                                 // zero (upper)
s_lshl_b64 s[32:33], s[32:33], 0x2                 // offset *= bytes/element
s_add_u32 s32, s29, s32                            // prepend address lower
s_addc_u32 s33, s30, s33                           // prepend address upper
v_mov_b32 v116, s32                                // sgpr->vgpr
v_mov_b32 v117, s33                                // sgpr->vgpr
s_mov_b64 s[34:35], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
v_mov_b32 v118, 0x4                                // bytes per element
v_mov_b32 v119, 0x0                                // zero
/* load component 0 */
v_mov_b32 v[vgprG2LB+0+0], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LB+0+0], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v119, vcc // gra += 1 (upper)
/* load component 1 */
v_mov_b32 v[vgprG2LB+0+1], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LB+0+1], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v119, vcc // gra += 1 (upper)
/* load component 2 */
v_mov_b32 v[vgprG2LB+0+2], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LB+0+2], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v119, vcc // gra += 1 (upper)
/* load component 3 */
v_mov_b32 v[vgprG2LB+0+3], 0x0                     // zero
v_cmpx_lt_u64 vcc, v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1], v[116:117] // addr < maxAddr
flat_load_dword v[vgprG2LB+0+3], v[vgprGlobalReadAddrB+0:vgprGlobalReadAddrB+0+1] // load single float
s_or_saveexec_b64 vcc, s[34:35]                    // all threads active
//v_add_u32 v[vgprGlobalReadAddrB+0+0], vcc, v[vgprGlobalReadAddrB+0+0], v118 // gra += 1 (lower)
//v_addc_u32 v[vgprGlobalReadAddrB+0+1], vcc, v[vgprGlobalReadAddrB+0+1], v119, vcc // gra += 1 (upper)
s_waitcnt vmcnt(0) // wait for global read
s_barrier

/* local write reset offsets a */
v_and_b32 v[vgprLocalWriteAddrA], 0x1fff, v[vgprLocalWriteAddrA] // reset to Red

/* local write reset offsets b */
v_and_b32 v[vgprLocalWriteAddrB], 0x1fff, v[vgprLocalWriteAddrB] // reset to Red

/* local write init pointers a */
/* N/A */

/* local write init pointers b */
/* N/A */

/* local write a */
ds_write_b128 v[vgprLocalWriteAddrA], v[vgprG2LA+0:vgprG2LA+0+3] offset:0 // lwoA_0_0_0_0 = (0*LSCA) + (0*LSPA)*MT0I = 0

/* local write b */
ds_write_b128 v[vgprLocalWriteAddrB], v[vgprG2LB+0:vgprG2LB+0+3] offset:0 // lwoB_0_0_0_0 = (0*LSCB) + (0*LSPB)*MT1J = 0
s_waitcnt lgkmcnt(0) // wait for local write
s_barrier

/* local read reset offsets a */
/* handled internally */
v_and_b32 v[vgprLocalReadAddrA], 0x1fff, v[vgprLocalReadAddrA] // reset Red,Blk -> Red

/* local read reset offsets b */
/* handled internally */
v_and_b32 v[vgprLocalReadAddrB], 0x1fff, v[vgprLocalReadAddrB] // reset Red,Blk -> Red

/* local read init pointers a */
/* N/A */

/* local read init pointers b */
/* N/A */

/* tail loop: macs */
s_cmp_ge_i32 s[sgprLoopCounters+0], 0x0            // LoopCounterK < EndCounter
s_cbranch_scc1 label_0005                          // don't enter LoopK
label_0004:

/* local read a */
ds_read_b128 v[vgprValuA+0:vgprValuA+0+3], v[vgprLocalReadAddrA] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuA+4:vgprValuA+4+3], v[vgprLocalReadAddrA] offset:256 // L -> Reg 0

/* local read b */
ds_read_b128 v[vgprValuB+0:vgprValuB+0+3], v[vgprLocalReadAddrB] offset:0 // L -> Reg 0
ds_read_b128 v[vgprValuB+4:vgprValuB+4+3], v[vgprLocalReadAddrB] offset:256 // L -> Reg 0

/* local read inc a */
s_mov_b32 s31, 0x200                               // inc
//v_add_u32 v[vgprLocalReadAddrA], vcc, s31, v[vgprLocalReadAddrA] // lrA += 512

/* local read inc b */
s_mov_b32 s31, 0x200                               // inc
//v_add_u32 v[vgprLocalReadAddrB], vcc, s31, v[vgprLocalReadAddrB] // lrB += 512
s_waitcnt lgkmcnt(0) // wait for local read
MAC_8x8
s_add_u32 s[sgprLoopCounters+0], s[sgprLoopCounters+0], 0x1 // counterK++
s_cmp_eq_i32 s[sgprLoopCounters+0], 0x0            // counterK==0
s_cbranch_scc1 label_0005                          // exit LoopK
s_branch label_0004                                // restart LoopK
label_0005:

/* shift vector components d0 */
v_mov_b32 v66, s[sgprWorkGroup0]                   // 
v_mul_i32_i24 v66, -0x80, v66                      // wg*MT
//v_add_u32 v66, vcc, s[sgprSizesFree+0], v66        // wgMT = Size - wg*MT
v_mov_b32 v64, 0x80                                // MT
v_cmp_lt_u32 s[14:15], v66, v64                    // wgMT < MT
v_cndmask_b32 v66, v64, v66, s[14:15]              // wgMT = (wgMT < MT) ? wgMT : MT
v_lshrrev_b32 v68, 2, v66                          // v68 = v66 / 4
v_and_b32 v67, 3, v66                              // v67 = v66 % 4
v_lshrrev_b32 v67, 2, v66                          // v67 = v66 / 4
v_and_b32 v69, 3, v66                              // v69 = v66 % 4
v_lshrrev_b32 v70, 4, v68                          // v70 = v68 / 16
v_and_b32 v71, 15, v68                             // v71 = v68 % 16
v_lshrrev_b32 v67, 4, v[vgprSerial]                // v67 = v[vgprSerial] / 16
v_and_b32 v72, 15, v[vgprSerial]                   // v72 = v[vgprSerial] % 16
v_lshrrev_b32 v73, 6, v66                          // v73 = v66 / 64
v_and_b32 v67, 63, v66                             // v67 = v66 % 64
v_lshrrev_b32 v67, 2, v66                          // v67 = v66 / 4
v_and_b32 v74, 3, v66                              // v74 = v66 % 4
v_mov_b32 v75, v74                                 // duplicate
v_lshrrev_b32 v74, 2, v75                          // v74 = v75 / 4
v_and_b32 v67, 3, v75                              // v67 = v75 % 4
//v_add_u32 v74, vcc, v73, v74                       // vId = 2 components
v_cmp_eq_u32 s[14:15], v72, v71                    // mask
v_mov_b32 v64, s14                                 // 
v_mov_b32 v65, s15                                 // 
v_cmp_eq_u32 vcc, v69, 0x1                         // wgMT%VW == 1
s_cbranch_vccnz label_0006                         // shift d0 r=1
v_cmp_eq_u32 vcc, v69, 0x2                         // wgMT%VW == 2
s_cbranch_vccnz label_0009                         // shift d0 r=2
v_cmp_eq_u32 vcc, v69, 0x3                         // wgMT%VW == 3
s_cbranch_vccnz label_0012                         // shift d0 r=3
s_branch label_0015                                // no shifting

/******************************************/
/* shift d0 r=1                           */
/******************************************/
label_0006:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0007                         // shift d0, r=1, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0008                         // shift d0, r=1, v=1

/* shift d0 r=1 v=0 */
label_0007:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v3                                   // rC[0+0*VW+0*TT0I] = rC[3+0*VW+0*TT0I]
v_mov_b32 v8, v11                                  // rC[0+0*VW+1*TT0I] = rC[3+0*VW+1*TT0I]
v_mov_b32 v16, v19                                 // rC[0+0*VW+2*TT0I] = rC[3+0*VW+2*TT0I]
v_mov_b32 v24, v27                                 // rC[0+0*VW+3*TT0I] = rC[3+0*VW+3*TT0I]
v_mov_b32 v32, v35                                 // rC[0+0*VW+4*TT0I] = rC[3+0*VW+4*TT0I]
v_mov_b32 v40, v43                                 // rC[0+0*VW+5*TT0I] = rC[3+0*VW+5*TT0I]
v_mov_b32 v48, v51                                 // rC[0+0*VW+6*TT0I] = rC[3+0*VW+6*TT0I]
v_mov_b32 v56, v59                                 // rC[0+0*VW+7*TT0I] = rC[3+0*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting

/* shift d0 r=1 v=1 */
label_0008:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v4, v7                                   // rC[0+1*VW+0*TT0I] = rC[3+1*VW+0*TT0I]
v_mov_b32 v12, v15                                 // rC[0+1*VW+1*TT0I] = rC[3+1*VW+1*TT0I]
v_mov_b32 v20, v23                                 // rC[0+1*VW+2*TT0I] = rC[3+1*VW+2*TT0I]
v_mov_b32 v28, v31                                 // rC[0+1*VW+3*TT0I] = rC[3+1*VW+3*TT0I]
v_mov_b32 v36, v39                                 // rC[0+1*VW+4*TT0I] = rC[3+1*VW+4*TT0I]
v_mov_b32 v44, v47                                 // rC[0+1*VW+5*TT0I] = rC[3+1*VW+5*TT0I]
v_mov_b32 v52, v55                                 // rC[0+1*VW+6*TT0I] = rC[3+1*VW+6*TT0I]
v_mov_b32 v60, v63                                 // rC[0+1*VW+7*TT0I] = rC[3+1*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting

/******************************************/
/* shift d0 r=2                           */
/******************************************/
label_0009:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0010                         // shift d0, r=2, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0011                         // shift d0, r=2, v=1

/* shift d0 r=2 v=0 */
label_0010:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v2                                   // rC[0+0*VW+0*TT0I] = rC[2+0*VW+0*TT0I]
v_mov_b32 v1, v3                                   // rC[1+0*VW+0*TT0I] = rC[3+0*VW+0*TT0I]
v_mov_b32 v8, v10                                  // rC[0+0*VW+1*TT0I] = rC[2+0*VW+1*TT0I]
v_mov_b32 v9, v11                                  // rC[1+0*VW+1*TT0I] = rC[3+0*VW+1*TT0I]
v_mov_b32 v16, v18                                 // rC[0+0*VW+2*TT0I] = rC[2+0*VW+2*TT0I]
v_mov_b32 v17, v19                                 // rC[1+0*VW+2*TT0I] = rC[3+0*VW+2*TT0I]
v_mov_b32 v24, v26                                 // rC[0+0*VW+3*TT0I] = rC[2+0*VW+3*TT0I]
v_mov_b32 v25, v27                                 // rC[1+0*VW+3*TT0I] = rC[3+0*VW+3*TT0I]
v_mov_b32 v32, v34                                 // rC[0+0*VW+4*TT0I] = rC[2+0*VW+4*TT0I]
v_mov_b32 v33, v35                                 // rC[1+0*VW+4*TT0I] = rC[3+0*VW+4*TT0I]
v_mov_b32 v40, v42                                 // rC[0+0*VW+5*TT0I] = rC[2+0*VW+5*TT0I]
v_mov_b32 v41, v43                                 // rC[1+0*VW+5*TT0I] = rC[3+0*VW+5*TT0I]
v_mov_b32 v48, v50                                 // rC[0+0*VW+6*TT0I] = rC[2+0*VW+6*TT0I]
v_mov_b32 v49, v51                                 // rC[1+0*VW+6*TT0I] = rC[3+0*VW+6*TT0I]
v_mov_b32 v56, v58                                 // rC[0+0*VW+7*TT0I] = rC[2+0*VW+7*TT0I]
v_mov_b32 v57, v59                                 // rC[1+0*VW+7*TT0I] = rC[3+0*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting

/* shift d0 r=2 v=1 */
label_0011:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v4, v6                                   // rC[0+1*VW+0*TT0I] = rC[2+1*VW+0*TT0I]
v_mov_b32 v5, v7                                   // rC[1+1*VW+0*TT0I] = rC[3+1*VW+0*TT0I]
v_mov_b32 v12, v14                                 // rC[0+1*VW+1*TT0I] = rC[2+1*VW+1*TT0I]
v_mov_b32 v13, v15                                 // rC[1+1*VW+1*TT0I] = rC[3+1*VW+1*TT0I]
v_mov_b32 v20, v22                                 // rC[0+1*VW+2*TT0I] = rC[2+1*VW+2*TT0I]
v_mov_b32 v21, v23                                 // rC[1+1*VW+2*TT0I] = rC[3+1*VW+2*TT0I]
v_mov_b32 v28, v30                                 // rC[0+1*VW+3*TT0I] = rC[2+1*VW+3*TT0I]
v_mov_b32 v29, v31                                 // rC[1+1*VW+3*TT0I] = rC[3+1*VW+3*TT0I]
v_mov_b32 v36, v38                                 // rC[0+1*VW+4*TT0I] = rC[2+1*VW+4*TT0I]
v_mov_b32 v37, v39                                 // rC[1+1*VW+4*TT0I] = rC[3+1*VW+4*TT0I]
v_mov_b32 v44, v46                                 // rC[0+1*VW+5*TT0I] = rC[2+1*VW+5*TT0I]
v_mov_b32 v45, v47                                 // rC[1+1*VW+5*TT0I] = rC[3+1*VW+5*TT0I]
v_mov_b32 v52, v54                                 // rC[0+1*VW+6*TT0I] = rC[2+1*VW+6*TT0I]
v_mov_b32 v53, v55                                 // rC[1+1*VW+6*TT0I] = rC[3+1*VW+6*TT0I]
v_mov_b32 v60, v62                                 // rC[0+1*VW+7*TT0I] = rC[2+1*VW+7*TT0I]
v_mov_b32 v61, v63                                 // rC[1+1*VW+7*TT0I] = rC[3+1*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting

/******************************************/
/* shift d0 r=3                           */
/******************************************/
label_0012:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0013                         // shift d0, r=3, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0014                         // shift d0, r=3, v=1

/* shift d0 r=3 v=0 */
label_0013:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v1                                   // rC[0+0*VW+0*TT0I] = rC[1+0*VW+0*TT0I]
v_mov_b32 v1, v2                                   // rC[1+0*VW+0*TT0I] = rC[2+0*VW+0*TT0I]
v_mov_b32 v2, v3                                   // rC[2+0*VW+0*TT0I] = rC[3+0*VW+0*TT0I]
v_mov_b32 v8, v9                                   // rC[0+0*VW+1*TT0I] = rC[1+0*VW+1*TT0I]
v_mov_b32 v9, v10                                  // rC[1+0*VW+1*TT0I] = rC[2+0*VW+1*TT0I]
v_mov_b32 v10, v11                                 // rC[2+0*VW+1*TT0I] = rC[3+0*VW+1*TT0I]
v_mov_b32 v16, v17                                 // rC[0+0*VW+2*TT0I] = rC[1+0*VW+2*TT0I]
v_mov_b32 v17, v18                                 // rC[1+0*VW+2*TT0I] = rC[2+0*VW+2*TT0I]
v_mov_b32 v18, v19                                 // rC[2+0*VW+2*TT0I] = rC[3+0*VW+2*TT0I]
v_mov_b32 v24, v25                                 // rC[0+0*VW+3*TT0I] = rC[1+0*VW+3*TT0I]
v_mov_b32 v25, v26                                 // rC[1+0*VW+3*TT0I] = rC[2+0*VW+3*TT0I]
v_mov_b32 v26, v27                                 // rC[2+0*VW+3*TT0I] = rC[3+0*VW+3*TT0I]
v_mov_b32 v32, v33                                 // rC[0+0*VW+4*TT0I] = rC[1+0*VW+4*TT0I]
v_mov_b32 v33, v34                                 // rC[1+0*VW+4*TT0I] = rC[2+0*VW+4*TT0I]
v_mov_b32 v34, v35                                 // rC[2+0*VW+4*TT0I] = rC[3+0*VW+4*TT0I]
v_mov_b32 v40, v41                                 // rC[0+0*VW+5*TT0I] = rC[1+0*VW+5*TT0I]
v_mov_b32 v41, v42                                 // rC[1+0*VW+5*TT0I] = rC[2+0*VW+5*TT0I]
v_mov_b32 v42, v43                                 // rC[2+0*VW+5*TT0I] = rC[3+0*VW+5*TT0I]
v_mov_b32 v48, v49                                 // rC[0+0*VW+6*TT0I] = rC[1+0*VW+6*TT0I]
v_mov_b32 v49, v50                                 // rC[1+0*VW+6*TT0I] = rC[2+0*VW+6*TT0I]
v_mov_b32 v50, v51                                 // rC[2+0*VW+6*TT0I] = rC[3+0*VW+6*TT0I]
v_mov_b32 v56, v57                                 // rC[0+0*VW+7*TT0I] = rC[1+0*VW+7*TT0I]
v_mov_b32 v57, v58                                 // rC[1+0*VW+7*TT0I] = rC[2+0*VW+7*TT0I]
v_mov_b32 v58, v59                                 // rC[2+0*VW+7*TT0I] = rC[3+0*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting

/* shift d0 r=3 v=1 */
label_0014:
v_cmpx_eq_u32 s[14:15], v72, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v4, v5                                   // rC[0+1*VW+0*TT0I] = rC[1+1*VW+0*TT0I]
v_mov_b32 v5, v6                                   // rC[1+1*VW+0*TT0I] = rC[2+1*VW+0*TT0I]
v_mov_b32 v6, v7                                   // rC[2+1*VW+0*TT0I] = rC[3+1*VW+0*TT0I]
v_mov_b32 v12, v13                                 // rC[0+1*VW+1*TT0I] = rC[1+1*VW+1*TT0I]
v_mov_b32 v13, v14                                 // rC[1+1*VW+1*TT0I] = rC[2+1*VW+1*TT0I]
v_mov_b32 v14, v15                                 // rC[2+1*VW+1*TT0I] = rC[3+1*VW+1*TT0I]
v_mov_b32 v20, v21                                 // rC[0+1*VW+2*TT0I] = rC[1+1*VW+2*TT0I]
v_mov_b32 v21, v22                                 // rC[1+1*VW+2*TT0I] = rC[2+1*VW+2*TT0I]
v_mov_b32 v22, v23                                 // rC[2+1*VW+2*TT0I] = rC[3+1*VW+2*TT0I]
v_mov_b32 v28, v29                                 // rC[0+1*VW+3*TT0I] = rC[1+1*VW+3*TT0I]
v_mov_b32 v29, v30                                 // rC[1+1*VW+3*TT0I] = rC[2+1*VW+3*TT0I]
v_mov_b32 v30, v31                                 // rC[2+1*VW+3*TT0I] = rC[3+1*VW+3*TT0I]
v_mov_b32 v36, v37                                 // rC[0+1*VW+4*TT0I] = rC[1+1*VW+4*TT0I]
v_mov_b32 v37, v38                                 // rC[1+1*VW+4*TT0I] = rC[2+1*VW+4*TT0I]
v_mov_b32 v38, v39                                 // rC[2+1*VW+4*TT0I] = rC[3+1*VW+4*TT0I]
v_mov_b32 v44, v45                                 // rC[0+1*VW+5*TT0I] = rC[1+1*VW+5*TT0I]
v_mov_b32 v45, v46                                 // rC[1+1*VW+5*TT0I] = rC[2+1*VW+5*TT0I]
v_mov_b32 v46, v47                                 // rC[2+1*VW+5*TT0I] = rC[3+1*VW+5*TT0I]
v_mov_b32 v52, v53                                 // rC[0+1*VW+6*TT0I] = rC[1+1*VW+6*TT0I]
v_mov_b32 v53, v54                                 // rC[1+1*VW+6*TT0I] = rC[2+1*VW+6*TT0I]
v_mov_b32 v54, v55                                 // rC[2+1*VW+6*TT0I] = rC[3+1*VW+6*TT0I]
v_mov_b32 v60, v61                                 // rC[0+1*VW+7*TT0I] = rC[1+1*VW+7*TT0I]
v_mov_b32 v61, v62                                 // rC[1+1*VW+7*TT0I] = rC[2+1*VW+7*TT0I]
v_mov_b32 v62, v63                                 // rC[2+1*VW+7*TT0I] = rC[3+1*VW+7*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0015                                // done shifting
label_0015: // end shift0

/* shift vector components d1 */
v_mov_b32 v66, s[sgprWorkGroup1]                   // 
v_mul_i32_i24 v66, -0x80, v66                      // wg*MT
//v_add_u32 v66, vcc, s[sgprSizesFree+1], v66        // wgMT = Size - wg*MT
v_mov_b32 v64, 0x80                                // MT
v_cmp_lt_u32 s[14:15], v66, v64                    // wgMT < MT
v_cndmask_b32 v66, v64, v66, s[14:15]              // wgMT = (wgMT < MT) ? wgMT : MT
v_lshrrev_b32 v68, 2, v66                          // v68 = v66 / 4
v_and_b32 v67, 3, v66                              // v67 = v66 % 4
v_lshrrev_b32 v67, 2, v66                          // v67 = v66 / 4
v_and_b32 v69, 3, v66                              // v69 = v66 % 4
v_lshrrev_b32 v70, 4, v68                          // v70 = v68 / 16
v_and_b32 v71, 15, v68                             // v71 = v68 % 16
v_lshrrev_b32 v72, 4, v[vgprSerial]                // v72 = v[vgprSerial] / 16
v_and_b32 v67, 15, v[vgprSerial]                   // v67 = v[vgprSerial] % 16
v_lshrrev_b32 v67, 4, v72                          // v67 = v72 / 16
v_and_b32 v73, 15, v72                             // v73 = v72 % 16
v_lshrrev_b32 v72, 6, v66                          // v72 = v66 / 64
v_and_b32 v67, 63, v66                             // v67 = v66 % 64
v_lshrrev_b32 v67, 2, v66                          // v67 = v66 / 4
v_and_b32 v74, 3, v66                              // v74 = v66 % 4
v_mov_b32 v75, v74                                 // duplicate
v_lshrrev_b32 v74, 2, v75                          // v74 = v75 / 4
v_and_b32 v67, 3, v75                              // v67 = v75 % 4
//v_add_u32 v74, vcc, v72, v74                       // vId = 2 components
v_cmp_eq_u32 s[14:15], v73, v71                    // mask
v_mov_b32 v64, s14                                 // 
v_mov_b32 v65, s15                                 // 
v_cmp_eq_u32 vcc, v69, 0x1                         // wgMT%VW == 1
s_cbranch_vccnz label_0018                         // shift d1 r=1
v_cmp_eq_u32 vcc, v69, 0x2                         // wgMT%VW == 2
s_cbranch_vccnz label_0021                         // shift d1 r=2
v_cmp_eq_u32 vcc, v69, 0x3                         // wgMT%VW == 3
s_cbranch_vccnz label_0024                         // shift d1 r=3
s_branch label_0027                                // no shifting

/******************************************/
/* shift d1 r=1                           */
/******************************************/
label_0018:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0019                         // shift d1, r=1, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0020                         // shift d1, r=1, v=1

/* shift d1 r=1 v=0 */
label_0019:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v24                                  // rC[0+0*TT0I*VW+0*TT0I] = rC[0+0*TT0I*VW+3*TT0I]
v_mov_b32 v1, v25                                  // rC[1+0*TT0I*VW+0*TT0I] = rC[1+0*TT0I*VW+3*TT0I]
v_mov_b32 v2, v26                                  // rC[2+0*TT0I*VW+0*TT0I] = rC[2+0*TT0I*VW+3*TT0I]
v_mov_b32 v3, v27                                  // rC[3+0*TT0I*VW+0*TT0I] = rC[3+0*TT0I*VW+3*TT0I]
v_mov_b32 v4, v28                                  // rC[4+0*TT0I*VW+0*TT0I] = rC[4+0*TT0I*VW+3*TT0I]
v_mov_b32 v5, v29                                  // rC[5+0*TT0I*VW+0*TT0I] = rC[5+0*TT0I*VW+3*TT0I]
v_mov_b32 v6, v30                                  // rC[6+0*TT0I*VW+0*TT0I] = rC[6+0*TT0I*VW+3*TT0I]
v_mov_b32 v7, v31                                  // rC[7+0*TT0I*VW+0*TT0I] = rC[7+0*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting

/* shift d1 r=1 v=1 */
label_0020:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v32, v56                                 // rC[0+1*TT0I*VW+0*TT0I] = rC[0+1*TT0I*VW+3*TT0I]
v_mov_b32 v33, v57                                 // rC[1+1*TT0I*VW+0*TT0I] = rC[1+1*TT0I*VW+3*TT0I]
v_mov_b32 v34, v58                                 // rC[2+1*TT0I*VW+0*TT0I] = rC[2+1*TT0I*VW+3*TT0I]
v_mov_b32 v35, v59                                 // rC[3+1*TT0I*VW+0*TT0I] = rC[3+1*TT0I*VW+3*TT0I]
v_mov_b32 v36, v60                                 // rC[4+1*TT0I*VW+0*TT0I] = rC[4+1*TT0I*VW+3*TT0I]
v_mov_b32 v37, v61                                 // rC[5+1*TT0I*VW+0*TT0I] = rC[5+1*TT0I*VW+3*TT0I]
v_mov_b32 v38, v62                                 // rC[6+1*TT0I*VW+0*TT0I] = rC[6+1*TT0I*VW+3*TT0I]
v_mov_b32 v39, v63                                 // rC[7+1*TT0I*VW+0*TT0I] = rC[7+1*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting

/******************************************/
/* shift d1 r=2                           */
/******************************************/
label_0021:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0022                         // shift d1, r=2, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0023                         // shift d1, r=2, v=1

/* shift d1 r=2 v=0 */
label_0022:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v16                                  // rC[0+0*TT0I*VW+0*TT0I] = rC[0+0*TT0I*VW+2*TT0I]
v_mov_b32 v8, v24                                  // rC[0+0*TT0I*VW+1*TT0I] = rC[0+0*TT0I*VW+3*TT0I]
v_mov_b32 v1, v17                                  // rC[1+0*TT0I*VW+0*TT0I] = rC[1+0*TT0I*VW+2*TT0I]
v_mov_b32 v9, v25                                  // rC[1+0*TT0I*VW+1*TT0I] = rC[1+0*TT0I*VW+3*TT0I]
v_mov_b32 v2, v18                                  // rC[2+0*TT0I*VW+0*TT0I] = rC[2+0*TT0I*VW+2*TT0I]
v_mov_b32 v10, v26                                 // rC[2+0*TT0I*VW+1*TT0I] = rC[2+0*TT0I*VW+3*TT0I]
v_mov_b32 v3, v19                                  // rC[3+0*TT0I*VW+0*TT0I] = rC[3+0*TT0I*VW+2*TT0I]
v_mov_b32 v11, v27                                 // rC[3+0*TT0I*VW+1*TT0I] = rC[3+0*TT0I*VW+3*TT0I]
v_mov_b32 v4, v20                                  // rC[4+0*TT0I*VW+0*TT0I] = rC[4+0*TT0I*VW+2*TT0I]
v_mov_b32 v12, v28                                 // rC[4+0*TT0I*VW+1*TT0I] = rC[4+0*TT0I*VW+3*TT0I]
v_mov_b32 v5, v21                                  // rC[5+0*TT0I*VW+0*TT0I] = rC[5+0*TT0I*VW+2*TT0I]
v_mov_b32 v13, v29                                 // rC[5+0*TT0I*VW+1*TT0I] = rC[5+0*TT0I*VW+3*TT0I]
v_mov_b32 v6, v22                                  // rC[6+0*TT0I*VW+0*TT0I] = rC[6+0*TT0I*VW+2*TT0I]
v_mov_b32 v14, v30                                 // rC[6+0*TT0I*VW+1*TT0I] = rC[6+0*TT0I*VW+3*TT0I]
v_mov_b32 v7, v23                                  // rC[7+0*TT0I*VW+0*TT0I] = rC[7+0*TT0I*VW+2*TT0I]
v_mov_b32 v15, v31                                 // rC[7+0*TT0I*VW+1*TT0I] = rC[7+0*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting

/* shift d1 r=2 v=1 */
label_0023:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v32, v48                                 // rC[0+1*TT0I*VW+0*TT0I] = rC[0+1*TT0I*VW+2*TT0I]
v_mov_b32 v40, v56                                 // rC[0+1*TT0I*VW+1*TT0I] = rC[0+1*TT0I*VW+3*TT0I]
v_mov_b32 v33, v49                                 // rC[1+1*TT0I*VW+0*TT0I] = rC[1+1*TT0I*VW+2*TT0I]
v_mov_b32 v41, v57                                 // rC[1+1*TT0I*VW+1*TT0I] = rC[1+1*TT0I*VW+3*TT0I]
v_mov_b32 v34, v50                                 // rC[2+1*TT0I*VW+0*TT0I] = rC[2+1*TT0I*VW+2*TT0I]
v_mov_b32 v42, v58                                 // rC[2+1*TT0I*VW+1*TT0I] = rC[2+1*TT0I*VW+3*TT0I]
v_mov_b32 v35, v51                                 // rC[3+1*TT0I*VW+0*TT0I] = rC[3+1*TT0I*VW+2*TT0I]
v_mov_b32 v43, v59                                 // rC[3+1*TT0I*VW+1*TT0I] = rC[3+1*TT0I*VW+3*TT0I]
v_mov_b32 v36, v52                                 // rC[4+1*TT0I*VW+0*TT0I] = rC[4+1*TT0I*VW+2*TT0I]
v_mov_b32 v44, v60                                 // rC[4+1*TT0I*VW+1*TT0I] = rC[4+1*TT0I*VW+3*TT0I]
v_mov_b32 v37, v53                                 // rC[5+1*TT0I*VW+0*TT0I] = rC[5+1*TT0I*VW+2*TT0I]
v_mov_b32 v45, v61                                 // rC[5+1*TT0I*VW+1*TT0I] = rC[5+1*TT0I*VW+3*TT0I]
v_mov_b32 v38, v54                                 // rC[6+1*TT0I*VW+0*TT0I] = rC[6+1*TT0I*VW+2*TT0I]
v_mov_b32 v46, v62                                 // rC[6+1*TT0I*VW+1*TT0I] = rC[6+1*TT0I*VW+3*TT0I]
v_mov_b32 v39, v55                                 // rC[7+1*TT0I*VW+0*TT0I] = rC[7+1*TT0I*VW+2*TT0I]
v_mov_b32 v47, v63                                 // rC[7+1*TT0I*VW+1*TT0I] = rC[7+1*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting

/******************************************/
/* shift d1 r=3                           */
/******************************************/
label_0024:
v_cmp_eq_u32 vcc, v74, 0x0                         // wgMT/(SG*VW) == 0
s_cbranch_vccnz label_0025                         // shift d1, r=3, v=0
v_cmp_eq_u32 vcc, v74, 0x1                         // wgMT/(SG*VW) == 1
s_cbranch_vccnz label_0026                         // shift d1, r=3, v=1

/* shift d1 r=3 v=0 */
label_0025:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v0, v8                                   // rC[0+0*TT0I*VW+0*TT0I] = rC[0+0*TT0I*VW+1*TT0I]
v_mov_b32 v8, v16                                  // rC[0+0*TT0I*VW+1*TT0I] = rC[0+0*TT0I*VW+2*TT0I]
v_mov_b32 v16, v24                                 // rC[0+0*TT0I*VW+2*TT0I] = rC[0+0*TT0I*VW+3*TT0I]
v_mov_b32 v1, v9                                   // rC[1+0*TT0I*VW+0*TT0I] = rC[1+0*TT0I*VW+1*TT0I]
v_mov_b32 v9, v17                                  // rC[1+0*TT0I*VW+1*TT0I] = rC[1+0*TT0I*VW+2*TT0I]
v_mov_b32 v17, v25                                 // rC[1+0*TT0I*VW+2*TT0I] = rC[1+0*TT0I*VW+3*TT0I]
v_mov_b32 v2, v10                                  // rC[2+0*TT0I*VW+0*TT0I] = rC[2+0*TT0I*VW+1*TT0I]
v_mov_b32 v10, v18                                 // rC[2+0*TT0I*VW+1*TT0I] = rC[2+0*TT0I*VW+2*TT0I]
v_mov_b32 v18, v26                                 // rC[2+0*TT0I*VW+2*TT0I] = rC[2+0*TT0I*VW+3*TT0I]
v_mov_b32 v3, v11                                  // rC[3+0*TT0I*VW+0*TT0I] = rC[3+0*TT0I*VW+1*TT0I]
v_mov_b32 v11, v19                                 // rC[3+0*TT0I*VW+1*TT0I] = rC[3+0*TT0I*VW+2*TT0I]
v_mov_b32 v19, v27                                 // rC[3+0*TT0I*VW+2*TT0I] = rC[3+0*TT0I*VW+3*TT0I]
v_mov_b32 v4, v12                                  // rC[4+0*TT0I*VW+0*TT0I] = rC[4+0*TT0I*VW+1*TT0I]
v_mov_b32 v12, v20                                 // rC[4+0*TT0I*VW+1*TT0I] = rC[4+0*TT0I*VW+2*TT0I]
v_mov_b32 v20, v28                                 // rC[4+0*TT0I*VW+2*TT0I] = rC[4+0*TT0I*VW+3*TT0I]
v_mov_b32 v5, v13                                  // rC[5+0*TT0I*VW+0*TT0I] = rC[5+0*TT0I*VW+1*TT0I]
v_mov_b32 v13, v21                                 // rC[5+0*TT0I*VW+1*TT0I] = rC[5+0*TT0I*VW+2*TT0I]
v_mov_b32 v21, v29                                 // rC[5+0*TT0I*VW+2*TT0I] = rC[5+0*TT0I*VW+3*TT0I]
v_mov_b32 v6, v14                                  // rC[6+0*TT0I*VW+0*TT0I] = rC[6+0*TT0I*VW+1*TT0I]
v_mov_b32 v14, v22                                 // rC[6+0*TT0I*VW+1*TT0I] = rC[6+0*TT0I*VW+2*TT0I]
v_mov_b32 v22, v30                                 // rC[6+0*TT0I*VW+2*TT0I] = rC[6+0*TT0I*VW+3*TT0I]
v_mov_b32 v7, v15                                  // rC[7+0*TT0I*VW+0*TT0I] = rC[7+0*TT0I*VW+1*TT0I]
v_mov_b32 v15, v23                                 // rC[7+0*TT0I*VW+1*TT0I] = rC[7+0*TT0I*VW+2*TT0I]
v_mov_b32 v23, v31                                 // rC[7+0*TT0I*VW+2*TT0I] = rC[7+0*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting

/* shift d1 r=3 v=1 */
label_0026:
v_cmpx_eq_u32 s[14:15], v73, v71                   // serial % SG == (wgMT/VECTOR_WIDTH)%SG
v_mov_b32 v32, v40                                 // rC[0+1*TT0I*VW+0*TT0I] = rC[0+1*TT0I*VW+1*TT0I]
v_mov_b32 v40, v48                                 // rC[0+1*TT0I*VW+1*TT0I] = rC[0+1*TT0I*VW+2*TT0I]
v_mov_b32 v48, v56                                 // rC[0+1*TT0I*VW+2*TT0I] = rC[0+1*TT0I*VW+3*TT0I]
v_mov_b32 v33, v41                                 // rC[1+1*TT0I*VW+0*TT0I] = rC[1+1*TT0I*VW+1*TT0I]
v_mov_b32 v41, v49                                 // rC[1+1*TT0I*VW+1*TT0I] = rC[1+1*TT0I*VW+2*TT0I]
v_mov_b32 v49, v57                                 // rC[1+1*TT0I*VW+2*TT0I] = rC[1+1*TT0I*VW+3*TT0I]
v_mov_b32 v34, v42                                 // rC[2+1*TT0I*VW+0*TT0I] = rC[2+1*TT0I*VW+1*TT0I]
v_mov_b32 v42, v50                                 // rC[2+1*TT0I*VW+1*TT0I] = rC[2+1*TT0I*VW+2*TT0I]
v_mov_b32 v50, v58                                 // rC[2+1*TT0I*VW+2*TT0I] = rC[2+1*TT0I*VW+3*TT0I]
v_mov_b32 v35, v43                                 // rC[3+1*TT0I*VW+0*TT0I] = rC[3+1*TT0I*VW+1*TT0I]
v_mov_b32 v43, v51                                 // rC[3+1*TT0I*VW+1*TT0I] = rC[3+1*TT0I*VW+2*TT0I]
v_mov_b32 v51, v59                                 // rC[3+1*TT0I*VW+2*TT0I] = rC[3+1*TT0I*VW+3*TT0I]
v_mov_b32 v36, v44                                 // rC[4+1*TT0I*VW+0*TT0I] = rC[4+1*TT0I*VW+1*TT0I]
v_mov_b32 v44, v52                                 // rC[4+1*TT0I*VW+1*TT0I] = rC[4+1*TT0I*VW+2*TT0I]
v_mov_b32 v52, v60                                 // rC[4+1*TT0I*VW+2*TT0I] = rC[4+1*TT0I*VW+3*TT0I]
v_mov_b32 v37, v45                                 // rC[5+1*TT0I*VW+0*TT0I] = rC[5+1*TT0I*VW+1*TT0I]
v_mov_b32 v45, v53                                 // rC[5+1*TT0I*VW+1*TT0I] = rC[5+1*TT0I*VW+2*TT0I]
v_mov_b32 v53, v61                                 // rC[5+1*TT0I*VW+2*TT0I] = rC[5+1*TT0I*VW+3*TT0I]
v_mov_b32 v38, v46                                 // rC[6+1*TT0I*VW+0*TT0I] = rC[6+1*TT0I*VW+1*TT0I]
v_mov_b32 v46, v54                                 // rC[6+1*TT0I*VW+1*TT0I] = rC[6+1*TT0I*VW+2*TT0I]
v_mov_b32 v54, v62                                 // rC[6+1*TT0I*VW+2*TT0I] = rC[6+1*TT0I*VW+3*TT0I]
v_mov_b32 v39, v47                                 // rC[7+1*TT0I*VW+0*TT0I] = rC[7+1*TT0I*VW+1*TT0I]
v_mov_b32 v47, v55                                 // rC[7+1*TT0I*VW+1*TT0I] = rC[7+1*TT0I*VW+2*TT0I]
v_mov_b32 v55, v63                                 // rC[7+1*TT0I*VW+2*TT0I] = rC[7+1*TT0I*VW+3*TT0I]
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // to restore all threads active
s_or_saveexec_b64 vcc, s[14:15]                    // all threads active
s_branch label_0027                                // done shifting
label_0027: // end shift0

/* not-LocalSplitU: global write indices */
v_lshrrev_b32 v67, 4, v[vgprSerial]                // v67 = v[vgprSerial] / 16
v_and_b32 v66, 15, v[vgprSerial]                   // v66 = v[vgprSerial] % 16
v_lshlrev_b32 v66, 2, v66                          // v66 = v66 * 4
v_lshlrev_b32 v67, 2, v67                          // v67 = v67 * 4
s_mul_i32 s14, 0x80, s[sgprWorkGroup0]             // s14 = wg0*MT0
s_mul_i32 s15, 0x80, s[sgprWorkGroup1]             // s15 = wg1*MT1
//v_add_u32 v66, vcc, s14, v66                       // coord0 = tid0*VW + wg0*MT0
//v_add_u32 v67, vcc, s15, v67                       // coord1 = tid1*VW + wg1*MT1
v_mov_b32 v64, s[sgprAddressC+0]                   // sgpr -> vgpr
v_mov_b32 v65, s[sgprAddressC+1]                   // sgpr -> vgpr

/* not-LocalSplitU: global write */
s_mov_b64 s[14:15], 0xFFFFFFFFFFFFFFFF             // full exec mask
s_cmpk_eq_u32 s[sgprBeta], 0x0                     // Beta == 0
s_cbranch_scc0 label_0036                          // Beta not not zero; so jump to B nonzero
s_mov_b32 s16, 0x0                                 // rMT0=0
s_add_u32 s18, -0x1, s[sgprNumWorkGroups0]         // 
s_cmp_lt_u32 s[sgprWorkGroup0], s18                // wg0 < nwg0-1
s_cbranch_scc1 label_0033                          // wg0 < nwg0-1 so skip rMT0 = Size0 % MT0
s_lshr_b32 s18, s[sgprSizesFree+0], 7              // s18 = s[sgprSizesFree+0] / 128
s_and_b32 s16, 127, s[sgprSizesFree+0]             // s16 = s[sgprSizesFree+0] % 128
label_0033:
s_cmpk_gt_u32 s16, 0x0                             // rMT0 > 0
s_cbranch_scc1 label_0035                          // edges required so jump to E1
s_mov_b32 s16, 0x0                                 // rMT1=0
s_add_u32 s18, -0x1, s[sgprNumWorkGroups1]         // 
s_cmp_lt_u32 s[sgprWorkGroup1], s18                // wg1 < nwg1-1
s_cbranch_scc1 label_0034                          // wg1 < nwg1-1 so skip rMT1 = Size1 % MT1
s_lshr_b32 s18, s[sgprSizesFree+1], 7              // s18 = s[sgprSizesFree+1] / 128
s_and_b32 s16, 127, s[sgprSizesFree+1]             // s16 = s[sgprSizesFree+1] % 128
label_0034:
s_cmpk_gt_u32 s16, 0x0                             // rMT1 > 0
s_cbranch_scc1 label_0035                          // edges required so jump to E1
label_0032:

/******************************************/
/* Global Write Batch:(0,0,0,0); (0,0,0,1); (0,0,0,2); (0,0,0,3); (0,0,1,0); (0,0,1,1); (0,0,1,2); (0,0,1,3); (0,0,2,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v0, s[sgprAlpha], v0                     // *= alpha
v_mul_f32 v1, s[sgprAlpha], v1                     // *= alpha
v_mul_f32 v2, s[sgprAlpha], v2                     // *= alpha
v_mul_f32 v3, s[sgprAlpha], v3                     // *= alpha
v_mul_f32 v8, s[sgprAlpha], v8                     // *= alpha
v_mul_f32 v9, s[sgprAlpha], v9                     // *= alpha
v_mul_f32 v10, s[sgprAlpha], v10                   // *= alpha
v_mul_f32 v11, s[sgprAlpha], v11                   // *= alpha
v_mul_f32 v16, s[sgprAlpha], v16                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v0 // store C
flat_store_dword v[75:76], v1 // store C
flat_store_dword v[77:78], v2 // store C
flat_store_dword v[79:80], v3 // store C
flat_store_dword v[81:82], v8 // store C
flat_store_dword v[83:84], v9 // store C
flat_store_dword v[85:86], v10 // store C
flat_store_dword v[87:88], v11 // store C
flat_store_dword v[89:90], v16 // store C

/******************************************/
/* Global Write Batch:(0,0,2,1); (0,0,2,2); (0,0,2,3); (0,0,3,0); (0,0,3,1); (0,0,3,2); (0,0,3,3); (0,1,0,0); (0,1,0,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v17, s[sgprAlpha], v17                   // *= alpha
v_mul_f32 v18, s[sgprAlpha], v18                   // *= alpha
v_mul_f32 v19, s[sgprAlpha], v19                   // *= alpha
v_mul_f32 v24, s[sgprAlpha], v24                   // *= alpha
v_mul_f32 v25, s[sgprAlpha], v25                   // *= alpha
v_mul_f32 v26, s[sgprAlpha], v26                   // *= alpha
v_mul_f32 v27, s[sgprAlpha], v27                   // *= alpha
v_mul_f32 v4, s[sgprAlpha], v4                     // *= alpha
v_mul_f32 v5, s[sgprAlpha], v5                     // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v17 // store C
flat_store_dword v[75:76], v18 // store C
flat_store_dword v[77:78], v19 // store C
flat_store_dword v[79:80], v24 // store C
flat_store_dword v[81:82], v25 // store C
flat_store_dword v[83:84], v26 // store C
flat_store_dword v[85:86], v27 // store C
flat_store_dword v[87:88], v4 // store C
flat_store_dword v[89:90], v5 // store C

/******************************************/
/* Global Write Batch:(0,1,0,2); (0,1,0,3); (0,1,1,0); (0,1,1,1); (0,1,1,2); (0,1,1,3); (0,1,2,0); (0,1,2,1); (0,1,2,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v6, s[sgprAlpha], v6                     // *= alpha
v_mul_f32 v7, s[sgprAlpha], v7                     // *= alpha
v_mul_f32 v12, s[sgprAlpha], v12                   // *= alpha
v_mul_f32 v13, s[sgprAlpha], v13                   // *= alpha
v_mul_f32 v14, s[sgprAlpha], v14                   // *= alpha
v_mul_f32 v15, s[sgprAlpha], v15                   // *= alpha
v_mul_f32 v20, s[sgprAlpha], v20                   // *= alpha
v_mul_f32 v21, s[sgprAlpha], v21                   // *= alpha
v_mul_f32 v22, s[sgprAlpha], v22                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v6 // store C
flat_store_dword v[75:76], v7 // store C
flat_store_dword v[77:78], v12 // store C
flat_store_dword v[79:80], v13 // store C
flat_store_dword v[81:82], v14 // store C
flat_store_dword v[83:84], v15 // store C
flat_store_dword v[85:86], v20 // store C
flat_store_dword v[87:88], v21 // store C
flat_store_dword v[89:90], v22 // store C

/******************************************/
/* Global Write Batch:(0,1,2,3); (0,1,3,0); (0,1,3,1); (0,1,3,2); (0,1,3,3); (1,0,0,0); (1,0,0,1); (1,0,0,2); (1,0,0,3) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v23, s[sgprAlpha], v23                   // *= alpha
v_mul_f32 v28, s[sgprAlpha], v28                   // *= alpha
v_mul_f32 v29, s[sgprAlpha], v29                   // *= alpha
v_mul_f32 v30, s[sgprAlpha], v30                   // *= alpha
v_mul_f32 v31, s[sgprAlpha], v31                   // *= alpha
v_mul_f32 v32, s[sgprAlpha], v32                   // *= alpha
v_mul_f32 v33, s[sgprAlpha], v33                   // *= alpha
v_mul_f32 v34, s[sgprAlpha], v34                   // *= alpha
v_mul_f32 v35, s[sgprAlpha], v35                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v23 // store C
flat_store_dword v[75:76], v28 // store C
flat_store_dword v[77:78], v29 // store C
flat_store_dword v[79:80], v30 // store C
flat_store_dword v[81:82], v31 // store C
flat_store_dword v[83:84], v32 // store C
flat_store_dword v[85:86], v33 // store C
flat_store_dword v[87:88], v34 // store C
flat_store_dword v[89:90], v35 // store C

/******************************************/
/* Global Write Batch:(1,0,1,0); (1,0,1,1); (1,0,1,2); (1,0,1,3); (1,0,2,0); (1,0,2,1); (1,0,2,2); (1,0,2,3); (1,0,3,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v40, s[sgprAlpha], v40                   // *= alpha
v_mul_f32 v41, s[sgprAlpha], v41                   // *= alpha
v_mul_f32 v42, s[sgprAlpha], v42                   // *= alpha
v_mul_f32 v43, s[sgprAlpha], v43                   // *= alpha
v_mul_f32 v48, s[sgprAlpha], v48                   // *= alpha
v_mul_f32 v49, s[sgprAlpha], v49                   // *= alpha
v_mul_f32 v50, s[sgprAlpha], v50                   // *= alpha
v_mul_f32 v51, s[sgprAlpha], v51                   // *= alpha
v_mul_f32 v56, s[sgprAlpha], v56                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v40 // store C
flat_store_dword v[75:76], v41 // store C
flat_store_dword v[77:78], v42 // store C
flat_store_dword v[79:80], v43 // store C
flat_store_dword v[81:82], v48 // store C
flat_store_dword v[83:84], v49 // store C
flat_store_dword v[85:86], v50 // store C
flat_store_dword v[87:88], v51 // store C
flat_store_dword v[89:90], v56 // store C

/******************************************/
/* Global Write Batch:(1,0,3,1); (1,0,3,2); (1,0,3,3); (1,1,0,0); (1,1,0,1); (1,1,0,2); (1,1,0,3); (1,1,1,0); (1,1,1,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v57, s[sgprAlpha], v57                   // *= alpha
v_mul_f32 v58, s[sgprAlpha], v58                   // *= alpha
v_mul_f32 v59, s[sgprAlpha], v59                   // *= alpha
v_mul_f32 v36, s[sgprAlpha], v36                   // *= alpha
v_mul_f32 v37, s[sgprAlpha], v37                   // *= alpha
v_mul_f32 v38, s[sgprAlpha], v38                   // *= alpha
v_mul_f32 v39, s[sgprAlpha], v39                   // *= alpha
v_mul_f32 v44, s[sgprAlpha], v44                   // *= alpha
v_mul_f32 v45, s[sgprAlpha], v45                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v57 // store C
flat_store_dword v[75:76], v58 // store C
flat_store_dword v[77:78], v59 // store C
flat_store_dword v[79:80], v36 // store C
flat_store_dword v[81:82], v37 // store C
flat_store_dword v[83:84], v38 // store C
flat_store_dword v[85:86], v39 // store C
flat_store_dword v[87:88], v44 // store C
flat_store_dword v[89:90], v45 // store C

/******************************************/
/* Global Write Batch:(1,1,1,2); (1,1,1,3); (1,1,2,0); (1,1,2,1); (1,1,2,2); (1,1,2,3); (1,1,3,0); (1,1,3,1); (1,1,3,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v46, s[sgprAlpha], v46                   // *= alpha
v_mul_f32 v47, s[sgprAlpha], v47                   // *= alpha
v_mul_f32 v52, s[sgprAlpha], v52                   // *= alpha
v_mul_f32 v53, s[sgprAlpha], v53                   // *= alpha
v_mul_f32 v54, s[sgprAlpha], v54                   // *= alpha
v_mul_f32 v55, s[sgprAlpha], v55                   // *= alpha
v_mul_f32 v60, s[sgprAlpha], v60                   // *= alpha
v_mul_f32 v61, s[sgprAlpha], v61                   // *= alpha
v_mul_f32 v62, s[sgprAlpha], v62                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v46 // store C
flat_store_dword v[75:76], v47 // store C
flat_store_dword v[77:78], v52 // store C
flat_store_dword v[79:80], v53 // store C
flat_store_dword v[81:82], v54 // store C
flat_store_dword v[83:84], v55 // store C
flat_store_dword v[85:86], v60 // store C
flat_store_dword v[87:88], v61 // store C
flat_store_dword v[89:90], v62 // store C

/******************************************/
/* Global Write Batch:(1,1,3,3)           */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v63, s[sgprAlpha], v63                   // *= alpha

/* apply mask, calc new C and issue write */
flat_store_dword v[73:74], v63 // store C
s_branch label_0043                                // jump to end
label_0035:
v_mov_b32 v73, s[sgprSizesFree+0]                  // free sizes sgpr -> vgpr
v_mov_b32 v74, s[sgprSizesFree+1]                  // free sizes sgpr -> vgpr

/******************************************/
/* Global Write Edge Batch:(0,0,0,0); (0,0,0,1); (0,0,0,2); (0,0,0,3); (0,0,1,0); (0,0,1,1); (0,0,1,2); (0,0,1,3); (0,0,2,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v0, s[sgprAlpha], v0                     // *= alpha
v_mul_f32 v1, s[sgprAlpha], v1                     // *= alpha
v_mul_f32 v2, s[sgprAlpha], v2                     // *= alpha
v_mul_f32 v3, s[sgprAlpha], v3                     // *= alpha
v_mul_f32 v8, s[sgprAlpha], v8                     // *= alpha
v_mul_f32 v9, s[sgprAlpha], v9                     // *= alpha
v_mul_f32 v10, s[sgprAlpha], v10                   // *= alpha
v_mul_f32 v11, s[sgprAlpha], v11                   // *= alpha
v_mul_f32 v16, s[sgprAlpha], v16                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v0 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v1 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v2 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v3 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v8 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v9 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v10 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v11 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v16 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(0,0,2,1); (0,0,2,2); (0,0,2,3); (0,0,3,0); (0,0,3,1); (0,0,3,2); (0,0,3,3); (0,1,0,0); (0,1,0,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v17, s[sgprAlpha], v17                   // *= alpha
v_mul_f32 v18, s[sgprAlpha], v18                   // *= alpha
v_mul_f32 v19, s[sgprAlpha], v19                   // *= alpha
v_mul_f32 v24, s[sgprAlpha], v24                   // *= alpha
v_mul_f32 v25, s[sgprAlpha], v25                   // *= alpha
v_mul_f32 v26, s[sgprAlpha], v26                   // *= alpha
v_mul_f32 v27, s[sgprAlpha], v27                   // *= alpha
v_mul_f32 v4, s[sgprAlpha], v4                     // *= alpha
v_mul_f32 v5, s[sgprAlpha], v5                     // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v17 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v18 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v19 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v24 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v25 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v26 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v27 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v4 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v5 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(0,1,0,2); (0,1,0,3); (0,1,1,0); (0,1,1,1); (0,1,1,2); (0,1,1,3); (0,1,2,0); (0,1,2,1); (0,1,2,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v6, s[sgprAlpha], v6                     // *= alpha
v_mul_f32 v7, s[sgprAlpha], v7                     // *= alpha
v_mul_f32 v12, s[sgprAlpha], v12                   // *= alpha
v_mul_f32 v13, s[sgprAlpha], v13                   // *= alpha
v_mul_f32 v14, s[sgprAlpha], v14                   // *= alpha
v_mul_f32 v15, s[sgprAlpha], v15                   // *= alpha
v_mul_f32 v20, s[sgprAlpha], v20                   // *= alpha
v_mul_f32 v21, s[sgprAlpha], v21                   // *= alpha
v_mul_f32 v22, s[sgprAlpha], v22                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v6 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v7 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v12 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v13 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v14 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v15 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v20 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v21 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v22 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(0,1,2,3); (0,1,3,0); (0,1,3,1); (0,1,3,2); (0,1,3,3); (1,0,0,0); (1,0,0,1); (1,0,0,2); (1,0,0,3) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v23, s[sgprAlpha], v23                   // *= alpha
v_mul_f32 v28, s[sgprAlpha], v28                   // *= alpha
v_mul_f32 v29, s[sgprAlpha], v29                   // *= alpha
v_mul_f32 v30, s[sgprAlpha], v30                   // *= alpha
v_mul_f32 v31, s[sgprAlpha], v31                   // *= alpha
v_mul_f32 v32, s[sgprAlpha], v32                   // *= alpha
v_mul_f32 v33, s[sgprAlpha], v33                   // *= alpha
v_mul_f32 v34, s[sgprAlpha], v34                   // *= alpha
v_mul_f32 v35, s[sgprAlpha], v35                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v23 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v28 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v29 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v30 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v31 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v32 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v33 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v34 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v35 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(1,0,1,0); (1,0,1,1); (1,0,1,2); (1,0,1,3); (1,0,2,0); (1,0,2,1); (1,0,2,2); (1,0,2,3); (1,0,3,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v40, s[sgprAlpha], v40                   // *= alpha
v_mul_f32 v41, s[sgprAlpha], v41                   // *= alpha
v_mul_f32 v42, s[sgprAlpha], v42                   // *= alpha
v_mul_f32 v43, s[sgprAlpha], v43                   // *= alpha
v_mul_f32 v48, s[sgprAlpha], v48                   // *= alpha
v_mul_f32 v49, s[sgprAlpha], v49                   // *= alpha
v_mul_f32 v50, s[sgprAlpha], v50                   // *= alpha
v_mul_f32 v51, s[sgprAlpha], v51                   // *= alpha
v_mul_f32 v56, s[sgprAlpha], v56                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v40 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v41 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v42 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v43 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v48 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v49 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v50 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v51 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v56 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(1,0,3,1); (1,0,3,2); (1,0,3,3); (1,1,0,0); (1,1,0,1); (1,1,0,2); (1,1,0,3); (1,1,1,0); (1,1,1,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v57, s[sgprAlpha], v57                   // *= alpha
v_mul_f32 v58, s[sgprAlpha], v58                   // *= alpha
v_mul_f32 v59, s[sgprAlpha], v59                   // *= alpha
v_mul_f32 v36, s[sgprAlpha], v36                   // *= alpha
v_mul_f32 v37, s[sgprAlpha], v37                   // *= alpha
v_mul_f32 v38, s[sgprAlpha], v38                   // *= alpha
v_mul_f32 v39, s[sgprAlpha], v39                   // *= alpha
v_mul_f32 v44, s[sgprAlpha], v44                   // *= alpha
v_mul_f32 v45, s[sgprAlpha], v45                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v57 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v58 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v59 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v36 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v37 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v38 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v39 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v44 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v45 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(1,1,1,2); (1,1,1,3); (1,1,2,0); (1,1,2,1); (1,1,2,2); (1,1,2,3); (1,1,3,0); (1,1,3,1); (1,1,3,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v46, s[sgprAlpha], v46                   // *= alpha
v_mul_f32 v47, s[sgprAlpha], v47                   // *= alpha
v_mul_f32 v52, s[sgprAlpha], v52                   // *= alpha
v_mul_f32 v53, s[sgprAlpha], v53                   // *= alpha
v_mul_f32 v54, s[sgprAlpha], v54                   // *= alpha
v_mul_f32 v55, s[sgprAlpha], v55                   // *= alpha
v_mul_f32 v60, s[sgprAlpha], v60                   // *= alpha
v_mul_f32 v61, s[sgprAlpha], v61                   // *= alpha
v_mul_f32 v62, s[sgprAlpha], v62                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v46 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
flat_store_dword v[77:78], v47 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
flat_store_dword v[79:80], v52 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
flat_store_dword v[81:82], v53 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
flat_store_dword v[83:84], v54 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
flat_store_dword v[85:86], v55 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
flat_store_dword v[87:88], v60 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
flat_store_dword v[89:90], v61 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
flat_store_dword v[91:92], v62 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Edge Batch:(1,1,3,3)      */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)

/* rC *= alpha */
v_mul_f32 v63, s[sgprAlpha], v63                   // *= alpha

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
flat_store_dword v[75:76], v63 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
s_branch label_0043                                // jump to end
label_0036:
s_mov_b32 s16, 0x0                                 // rMT0=0
s_add_u32 s18, -0x1, s[sgprNumWorkGroups0]         // 
s_cmp_lt_u32 s[sgprWorkGroup0], s18                // wg0 < nwg0-1
s_cbranch_scc1 label_0040                          // wg0 < nwg0-1 so skip rMT0 = Size0 % MT0
s_lshr_b32 s18, s[sgprSizesFree+0], 7              // s18 = s[sgprSizesFree+0] / 128
s_and_b32 s16, 127, s[sgprSizesFree+0]             // s16 = s[sgprSizesFree+0] % 128
label_0040:
s_cmpk_gt_u32 s16, 0x0                             // rMT0 > 0
s_cbranch_scc1 label_0042                          // edges required so jump to E1
s_mov_b32 s16, 0x0                                 // rMT1=0
s_add_u32 s18, -0x1, s[sgprNumWorkGroups1]         // 
s_cmp_lt_u32 s[sgprWorkGroup1], s18                // wg1 < nwg1-1
s_cbranch_scc1 label_0041                          // wg1 < nwg1-1 so skip rMT1 = Size1 % MT1
s_lshr_b32 s18, s[sgprSizesFree+1], 7              // s18 = s[sgprSizesFree+1] / 128
s_and_b32 s16, 127, s[sgprSizesFree+1]             // s16 = s[sgprSizesFree+1] % 128
label_0041:
s_cmpk_gt_u32 s16, 0x0                             // rMT1 > 0
s_cbranch_scc1 label_0042                          // edges required so jump to E1
label_0039:

/******************************************/
/* Global Write Beta Batch:(0,0,0,0); (0,0,0,1); (0,0,0,2); (0,0,0,3); (0,0,1,0); (0,0,1,1); (0,0,1,2); (0,0,1,3); (0,0,2,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v0, s[sgprAlpha], v0                     // *= alpha
v_mul_f32 v1, s[sgprAlpha], v1                     // *= alpha
v_mul_f32 v2, s[sgprAlpha], v2                     // *= alpha
v_mul_f32 v3, s[sgprAlpha], v3                     // *= alpha
v_mul_f32 v8, s[sgprAlpha], v8                     // *= alpha
v_mul_f32 v9, s[sgprAlpha], v9                     // *= alpha
v_mul_f32 v10, s[sgprAlpha], v10                   // *= alpha
v_mul_f32 v11, s[sgprAlpha], v11                   // *= alpha
v_mul_f32 v16, s[sgprAlpha], v16                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v0, v91, v0                              // sum*alpha + C*beta
flat_store_dword v[73:74], v0 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v1, v92, v1                              // sum*alpha + C*beta
flat_store_dword v[75:76], v1 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v2, v93, v2                              // sum*alpha + C*beta
flat_store_dword v[77:78], v2 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v3, v94, v3                              // sum*alpha + C*beta
flat_store_dword v[79:80], v3 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v8, v95, v8                              // sum*alpha + C*beta
flat_store_dword v[81:82], v8 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v9, v96, v9                              // sum*alpha + C*beta
flat_store_dword v[83:84], v9 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v10, v97, v10                            // sum*alpha + C*beta
flat_store_dword v[85:86], v10 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v11, v98, v11                            // sum*alpha + C*beta
flat_store_dword v[87:88], v11 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v16, v99, v16                            // sum*alpha + C*beta
flat_store_dword v[89:90], v16 // store C

/******************************************/
/* Global Write Beta Batch:(0,0,2,1); (0,0,2,2); (0,0,2,3); (0,0,3,0); (0,0,3,1); (0,0,3,2); (0,0,3,3); (0,1,0,0); (0,1,0,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v17, s[sgprAlpha], v17                   // *= alpha
v_mul_f32 v18, s[sgprAlpha], v18                   // *= alpha
v_mul_f32 v19, s[sgprAlpha], v19                   // *= alpha
v_mul_f32 v24, s[sgprAlpha], v24                   // *= alpha
v_mul_f32 v25, s[sgprAlpha], v25                   // *= alpha
v_mul_f32 v26, s[sgprAlpha], v26                   // *= alpha
v_mul_f32 v27, s[sgprAlpha], v27                   // *= alpha
v_mul_f32 v4, s[sgprAlpha], v4                     // *= alpha
v_mul_f32 v5, s[sgprAlpha], v5                     // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v17, v91, v17                            // sum*alpha + C*beta
flat_store_dword v[73:74], v17 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v18, v92, v18                            // sum*alpha + C*beta
flat_store_dword v[75:76], v18 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v19, v93, v19                            // sum*alpha + C*beta
flat_store_dword v[77:78], v19 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v24, v94, v24                            // sum*alpha + C*beta
flat_store_dword v[79:80], v24 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v25, v95, v25                            // sum*alpha + C*beta
flat_store_dword v[81:82], v25 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v26, v96, v26                            // sum*alpha + C*beta
flat_store_dword v[83:84], v26 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v27, v97, v27                            // sum*alpha + C*beta
flat_store_dword v[85:86], v27 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v4, v98, v4                              // sum*alpha + C*beta
flat_store_dword v[87:88], v4 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v5, v99, v5                              // sum*alpha + C*beta
flat_store_dword v[89:90], v5 // store C

/******************************************/
/* Global Write Beta Batch:(0,1,0,2); (0,1,0,3); (0,1,1,0); (0,1,1,1); (0,1,1,2); (0,1,1,3); (0,1,2,0); (0,1,2,1); (0,1,2,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v6, s[sgprAlpha], v6                     // *= alpha
v_mul_f32 v7, s[sgprAlpha], v7                     // *= alpha
v_mul_f32 v12, s[sgprAlpha], v12                   // *= alpha
v_mul_f32 v13, s[sgprAlpha], v13                   // *= alpha
v_mul_f32 v14, s[sgprAlpha], v14                   // *= alpha
v_mul_f32 v15, s[sgprAlpha], v15                   // *= alpha
v_mul_f32 v20, s[sgprAlpha], v20                   // *= alpha
v_mul_f32 v21, s[sgprAlpha], v21                   // *= alpha
v_mul_f32 v22, s[sgprAlpha], v22                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v6, v91, v6                              // sum*alpha + C*beta
flat_store_dword v[73:74], v6 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v7, v92, v7                              // sum*alpha + C*beta
flat_store_dword v[75:76], v7 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v12, v93, v12                            // sum*alpha + C*beta
flat_store_dword v[77:78], v12 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v13, v94, v13                            // sum*alpha + C*beta
flat_store_dword v[79:80], v13 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v14, v95, v14                            // sum*alpha + C*beta
flat_store_dword v[81:82], v14 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v15, v96, v15                            // sum*alpha + C*beta
flat_store_dword v[83:84], v15 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v20, v97, v20                            // sum*alpha + C*beta
flat_store_dword v[85:86], v20 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v21, v98, v21                            // sum*alpha + C*beta
flat_store_dword v[87:88], v21 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v22, v99, v22                            // sum*alpha + C*beta
flat_store_dword v[89:90], v22 // store C

/******************************************/
/* Global Write Beta Batch:(0,1,2,3); (0,1,3,0); (0,1,3,1); (0,1,3,2); (0,1,3,3); (1,0,0,0); (1,0,0,1); (1,0,0,2); (1,0,0,3) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v23, s[sgprAlpha], v23                   // *= alpha
v_mul_f32 v28, s[sgprAlpha], v28                   // *= alpha
v_mul_f32 v29, s[sgprAlpha], v29                   // *= alpha
v_mul_f32 v30, s[sgprAlpha], v30                   // *= alpha
v_mul_f32 v31, s[sgprAlpha], v31                   // *= alpha
v_mul_f32 v32, s[sgprAlpha], v32                   // *= alpha
v_mul_f32 v33, s[sgprAlpha], v33                   // *= alpha
v_mul_f32 v34, s[sgprAlpha], v34                   // *= alpha
v_mul_f32 v35, s[sgprAlpha], v35                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v23, v91, v23                            // sum*alpha + C*beta
flat_store_dword v[73:74], v23 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v28, v92, v28                            // sum*alpha + C*beta
flat_store_dword v[75:76], v28 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v29, v93, v29                            // sum*alpha + C*beta
flat_store_dword v[77:78], v29 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v30, v94, v30                            // sum*alpha + C*beta
flat_store_dword v[79:80], v30 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v31, v95, v31                            // sum*alpha + C*beta
flat_store_dword v[81:82], v31 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v32, v96, v32                            // sum*alpha + C*beta
flat_store_dword v[83:84], v32 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v33, v97, v33                            // sum*alpha + C*beta
flat_store_dword v[85:86], v33 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v34, v98, v34                            // sum*alpha + C*beta
flat_store_dword v[87:88], v34 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v35, v99, v35                            // sum*alpha + C*beta
flat_store_dword v[89:90], v35 // store C

/******************************************/
/* Global Write Beta Batch:(1,0,1,0); (1,0,1,1); (1,0,1,2); (1,0,1,3); (1,0,2,0); (1,0,2,1); (1,0,2,2); (1,0,2,3); (1,0,3,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v40, s[sgprAlpha], v40                   // *= alpha
v_mul_f32 v41, s[sgprAlpha], v41                   // *= alpha
v_mul_f32 v42, s[sgprAlpha], v42                   // *= alpha
v_mul_f32 v43, s[sgprAlpha], v43                   // *= alpha
v_mul_f32 v48, s[sgprAlpha], v48                   // *= alpha
v_mul_f32 v49, s[sgprAlpha], v49                   // *= alpha
v_mul_f32 v50, s[sgprAlpha], v50                   // *= alpha
v_mul_f32 v51, s[sgprAlpha], v51                   // *= alpha
v_mul_f32 v56, s[sgprAlpha], v56                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v40, v91, v40                            // sum*alpha + C*beta
flat_store_dword v[73:74], v40 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v41, v92, v41                            // sum*alpha + C*beta
flat_store_dword v[75:76], v41 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v42, v93, v42                            // sum*alpha + C*beta
flat_store_dword v[77:78], v42 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v43, v94, v43                            // sum*alpha + C*beta
flat_store_dword v[79:80], v43 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v48, v95, v48                            // sum*alpha + C*beta
flat_store_dword v[81:82], v48 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v49, v96, v49                            // sum*alpha + C*beta
flat_store_dword v[83:84], v49 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v50, v97, v50                            // sum*alpha + C*beta
flat_store_dword v[85:86], v50 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v51, v98, v51                            // sum*alpha + C*beta
flat_store_dword v[87:88], v51 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v56, v99, v56                            // sum*alpha + C*beta
flat_store_dword v[89:90], v56 // store C

/******************************************/
/* Global Write Beta Batch:(1,0,3,1); (1,0,3,2); (1,0,3,3); (1,1,0,0); (1,1,0,1); (1,1,0,2); (1,1,0,3); (1,1,1,0); (1,1,1,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v57, s[sgprAlpha], v57                   // *= alpha
v_mul_f32 v58, s[sgprAlpha], v58                   // *= alpha
v_mul_f32 v59, s[sgprAlpha], v59                   // *= alpha
v_mul_f32 v36, s[sgprAlpha], v36                   // *= alpha
v_mul_f32 v37, s[sgprAlpha], v37                   // *= alpha
v_mul_f32 v38, s[sgprAlpha], v38                   // *= alpha
v_mul_f32 v39, s[sgprAlpha], v39                   // *= alpha
v_mul_f32 v44, s[sgprAlpha], v44                   // *= alpha
v_mul_f32 v45, s[sgprAlpha], v45                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v57, v91, v57                            // sum*alpha + C*beta
flat_store_dword v[73:74], v57 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v58, v92, v58                            // sum*alpha + C*beta
flat_store_dword v[75:76], v58 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v59, v93, v59                            // sum*alpha + C*beta
flat_store_dword v[77:78], v59 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v36, v94, v36                            // sum*alpha + C*beta
flat_store_dword v[79:80], v36 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v37, v95, v37                            // sum*alpha + C*beta
flat_store_dword v[81:82], v37 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v38, v96, v38                            // sum*alpha + C*beta
flat_store_dword v[83:84], v38 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v39, v97, v39                            // sum*alpha + C*beta
flat_store_dword v[85:86], v39 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v44, v98, v44                            // sum*alpha + C*beta
flat_store_dword v[87:88], v44 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v45, v99, v45                            // sum*alpha + C*beta
flat_store_dword v[89:90], v45 // store C

/******************************************/
/* Global Write Beta Batch:(1,1,1,2); (1,1,1,3); (1,1,2,0); (1,1,2,1); (1,1,2,2); (1,1,2,3); (1,1,3,0); (1,1,3,1); (1,1,3,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v91, v[73:74]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v92, v[75:76]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[77:78]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[79:80]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[81:82]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[83:84]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[85:86]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[87:88]                      // load C
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[89:90]                      // load C

/* rC *= alpha */
v_mul_f32 v46, s[sgprAlpha], v46                   // *= alpha
v_mul_f32 v47, s[sgprAlpha], v47                   // *= alpha
v_mul_f32 v52, s[sgprAlpha], v52                   // *= alpha
v_mul_f32 v53, s[sgprAlpha], v53                   // *= alpha
v_mul_f32 v54, s[sgprAlpha], v54                   // *= alpha
v_mul_f32 v55, s[sgprAlpha], v55                   // *= alpha
v_mul_f32 v60, s[sgprAlpha], v60                   // *= alpha
v_mul_f32 v61, s[sgprAlpha], v61                   // *= alpha
v_mul_f32 v62, s[sgprAlpha], v62                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v91, s[sgprBeta], v91                    // v91 = C*beta
v_add_f32 v46, v91, v46                            // sum*alpha + C*beta
flat_store_dword v[73:74], v46 // store C
v_mul_f32 v92, s[sgprBeta], v92                    // v92 = C*beta
v_add_f32 v47, v92, v47                            // sum*alpha + C*beta
flat_store_dword v[75:76], v47 // store C
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v52, v93, v52                            // sum*alpha + C*beta
flat_store_dword v[77:78], v52 // store C
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v53, v94, v53                            // sum*alpha + C*beta
flat_store_dword v[79:80], v53 // store C
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v54, v95, v54                            // sum*alpha + C*beta
flat_store_dword v[81:82], v54 // store C
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v55, v96, v55                            // sum*alpha + C*beta
flat_store_dword v[83:84], v55 // store C
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v60, v97, v60                            // sum*alpha + C*beta
flat_store_dword v[85:86], v60 // store C
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v61, v98, v61                            // sum*alpha + C*beta
flat_store_dword v[87:88], v61 // store C
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v62, v99, v62                            // sum*alpha + C*beta
flat_store_dword v[89:90], v62 // store C

/******************************************/
/* Global Write Beta Batch:(1,1,3,3)      */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
GLOBAL_OFFSET_C 73, 68, 69, 70
//v_add_u32 v73, vcc, v64, v73                       // addr = C + index*bytes (lo)
//v_addc_u32 v74, vcc, v65, v74, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v75, v[73:74]                      // load C

/* rC *= alpha */
v_mul_f32 v63, s[sgprAlpha], v63                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
v_mul_f32 v75, s[sgprBeta], v75                    // v75 = C*beta
v_add_f32 v63, v75, v63                            // sum*alpha + C*beta
flat_store_dword v[73:74], v63 // store C
s_branch label_0043                                // jump to end
label_0042:
v_mov_b32 v73, s[sgprSizesFree+0]                  // free sizes sgpr -> vgpr
v_mov_b32 v74, s[sgprSizesFree+1]                  // free sizes sgpr -> vgpr

/******************************************/
/* Global Write Beta Edge Batch:(0,0,0,0); (0,0,0,1); (0,0,0,2); (0,0,0,3); (0,0,1,0); (0,0,1,1); (0,0,1,2); (0,0,1,3); (0,0,2,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v0, s[sgprAlpha], v0                     // *= alpha
v_mul_f32 v1, s[sgprAlpha], v1                     // *= alpha
v_mul_f32 v2, s[sgprAlpha], v2                     // *= alpha
v_mul_f32 v3, s[sgprAlpha], v3                     // *= alpha
v_mul_f32 v8, s[sgprAlpha], v8                     // *= alpha
v_mul_f32 v9, s[sgprAlpha], v9                     // *= alpha
v_mul_f32 v10, s[sgprAlpha], v10                   // *= alpha
v_mul_f32 v11, s[sgprAlpha], v11                   // *= alpha
v_mul_f32 v16, s[sgprAlpha], v16                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v0, v93, v0                              // sum*alpha + C*beta
flat_store_dword v[75:76], v0 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v1, v94, v1                              // sum*alpha + C*beta
flat_store_dword v[77:78], v1 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v2, v95, v2                              // sum*alpha + C*beta
flat_store_dword v[79:80], v2 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v3, v96, v3                              // sum*alpha + C*beta
flat_store_dword v[81:82], v3 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v8, v97, v8                              // sum*alpha + C*beta
flat_store_dword v[83:84], v8 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v9, v98, v9                              // sum*alpha + C*beta
flat_store_dword v[85:86], v9 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v10, v99, v10                            // sum*alpha + C*beta
flat_store_dword v[87:88], v10 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v11, v100, v11                           // sum*alpha + C*beta
flat_store_dword v[89:90], v11 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v16, v101, v16                           // sum*alpha + C*beta
flat_store_dword v[91:92], v16 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(0,0,2,1); (0,0,2,2); (0,0,2,3); (0,0,3,0); (0,0,3,1); (0,0,3,2); (0,0,3,3); (0,1,0,0); (0,1,0,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v17, s[sgprAlpha], v17                   // *= alpha
v_mul_f32 v18, s[sgprAlpha], v18                   // *= alpha
v_mul_f32 v19, s[sgprAlpha], v19                   // *= alpha
v_mul_f32 v24, s[sgprAlpha], v24                   // *= alpha
v_mul_f32 v25, s[sgprAlpha], v25                   // *= alpha
v_mul_f32 v26, s[sgprAlpha], v26                   // *= alpha
v_mul_f32 v27, s[sgprAlpha], v27                   // *= alpha
v_mul_f32 v4, s[sgprAlpha], v4                     // *= alpha
v_mul_f32 v5, s[sgprAlpha], v5                     // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v17, v93, v17                            // sum*alpha + C*beta
flat_store_dword v[75:76], v17 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v18, v94, v18                            // sum*alpha + C*beta
flat_store_dword v[77:78], v18 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v19, v95, v19                            // sum*alpha + C*beta
flat_store_dword v[79:80], v19 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v24, v96, v24                            // sum*alpha + C*beta
flat_store_dword v[81:82], v24 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v25, v97, v25                            // sum*alpha + C*beta
flat_store_dword v[83:84], v25 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v26, v98, v26                            // sum*alpha + C*beta
flat_store_dword v[85:86], v26 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v27, v99, v27                            // sum*alpha + C*beta
flat_store_dword v[87:88], v27 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v4, v100, v4                             // sum*alpha + C*beta
flat_store_dword v[89:90], v4 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v5, v101, v5                             // sum*alpha + C*beta
flat_store_dword v[91:92], v5 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(0,1,0,2); (0,1,0,3); (0,1,1,0); (0,1,1,1); (0,1,1,2); (0,1,1,3); (0,1,2,0); (0,1,2,1); (0,1,2,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v6, s[sgprAlpha], v6                     // *= alpha
v_mul_f32 v7, s[sgprAlpha], v7                     // *= alpha
v_mul_f32 v12, s[sgprAlpha], v12                   // *= alpha
v_mul_f32 v13, s[sgprAlpha], v13                   // *= alpha
v_mul_f32 v14, s[sgprAlpha], v14                   // *= alpha
v_mul_f32 v15, s[sgprAlpha], v15                   // *= alpha
v_mul_f32 v20, s[sgprAlpha], v20                   // *= alpha
v_mul_f32 v21, s[sgprAlpha], v21                   // *= alpha
v_mul_f32 v22, s[sgprAlpha], v22                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v6, v93, v6                              // sum*alpha + C*beta
flat_store_dword v[75:76], v6 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v7, v94, v7                              // sum*alpha + C*beta
flat_store_dword v[77:78], v7 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v12, v95, v12                            // sum*alpha + C*beta
flat_store_dword v[79:80], v12 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v13, v96, v13                            // sum*alpha + C*beta
flat_store_dword v[81:82], v13 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v14, v97, v14                            // sum*alpha + C*beta
flat_store_dword v[83:84], v14 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v15, v98, v15                            // sum*alpha + C*beta
flat_store_dword v[85:86], v15 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v20, v99, v20                            // sum*alpha + C*beta
flat_store_dword v[87:88], v20 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v21, v100, v21                           // sum*alpha + C*beta
flat_store_dword v[89:90], v21 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v22, v101, v22                           // sum*alpha + C*beta
flat_store_dword v[91:92], v22 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(0,1,2,3); (0,1,3,0); (0,1,3,1); (0,1,3,2); (0,1,3,3); (1,0,0,0); (1,0,0,1); (1,0,0,2); (1,0,0,3) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 0                            // v69 = 0 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v23, s[sgprAlpha], v23                   // *= alpha
v_mul_f32 v28, s[sgprAlpha], v28                   // *= alpha
v_mul_f32 v29, s[sgprAlpha], v29                   // *= alpha
v_mul_f32 v30, s[sgprAlpha], v30                   // *= alpha
v_mul_f32 v31, s[sgprAlpha], v31                   // *= alpha
v_mul_f32 v32, s[sgprAlpha], v32                   // *= alpha
v_mul_f32 v33, s[sgprAlpha], v33                   // *= alpha
v_mul_f32 v34, s[sgprAlpha], v34                   // *= alpha
v_mul_f32 v35, s[sgprAlpha], v35                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v23, v93, v23                            // sum*alpha + C*beta
flat_store_dword v[75:76], v23 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v28, v94, v28                            // sum*alpha + C*beta
flat_store_dword v[77:78], v28 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v29, v95, v29                            // sum*alpha + C*beta
flat_store_dword v[79:80], v29 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v30, v96, v30                            // sum*alpha + C*beta
flat_store_dword v[81:82], v30 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v31, v97, v31                            // sum*alpha + C*beta
flat_store_dword v[83:84], v31 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v32, v98, v32                            // sum*alpha + C*beta
flat_store_dword v[85:86], v32 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v33, v99, v33                            // sum*alpha + C*beta
flat_store_dword v[87:88], v33 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v34, v100, v34                           // sum*alpha + C*beta
flat_store_dword v[89:90], v34 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v35, v101, v35                           // sum*alpha + C*beta
flat_store_dword v[91:92], v35 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(1,0,1,0); (1,0,1,1); (1,0,1,2); (1,0,1,3); (1,0,2,0); (1,0,2,1); (1,0,2,2); (1,0,2,3); (1,0,3,0) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v40, s[sgprAlpha], v40                   // *= alpha
v_mul_f32 v41, s[sgprAlpha], v41                   // *= alpha
v_mul_f32 v42, s[sgprAlpha], v42                   // *= alpha
v_mul_f32 v43, s[sgprAlpha], v43                   // *= alpha
v_mul_f32 v48, s[sgprAlpha], v48                   // *= alpha
v_mul_f32 v49, s[sgprAlpha], v49                   // *= alpha
v_mul_f32 v50, s[sgprAlpha], v50                   // *= alpha
v_mul_f32 v51, s[sgprAlpha], v51                   // *= alpha
v_mul_f32 v56, s[sgprAlpha], v56                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v40, v93, v40                            // sum*alpha + C*beta
flat_store_dword v[75:76], v40 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v41, v94, v41                            // sum*alpha + C*beta
flat_store_dword v[77:78], v41 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v42, v95, v42                            // sum*alpha + C*beta
flat_store_dword v[79:80], v42 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v43, v96, v43                            // sum*alpha + C*beta
flat_store_dword v[81:82], v43 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v48, v97, v48                            // sum*alpha + C*beta
flat_store_dword v[83:84], v48 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v49, v98, v49                            // sum*alpha + C*beta
flat_store_dword v[85:86], v49 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v50, v99, v50                            // sum*alpha + C*beta
flat_store_dword v[87:88], v50 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v51, v100, v51                           // sum*alpha + C*beta
flat_store_dword v[89:90], v51 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v56, v101, v56                           // sum*alpha + C*beta
flat_store_dword v[91:92], v56 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(1,0,3,1); (1,0,3,2); (1,0,3,3); (1,1,0,0); (1,1,0,1); (1,1,0,2); (1,1,0,3); (1,1,1,0); (1,1,1,1) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 0                            // v68 = 0 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x0, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v57, s[sgprAlpha], v57                   // *= alpha
v_mul_f32 v58, s[sgprAlpha], v58                   // *= alpha
v_mul_f32 v59, s[sgprAlpha], v59                   // *= alpha
v_mul_f32 v36, s[sgprAlpha], v36                   // *= alpha
v_mul_f32 v37, s[sgprAlpha], v37                   // *= alpha
v_mul_f32 v38, s[sgprAlpha], v38                   // *= alpha
v_mul_f32 v39, s[sgprAlpha], v39                   // *= alpha
v_mul_f32 v44, s[sgprAlpha], v44                   // *= alpha
v_mul_f32 v45, s[sgprAlpha], v45                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v57, v93, v57                            // sum*alpha + C*beta
flat_store_dword v[75:76], v57 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v58, v94, v58                            // sum*alpha + C*beta
flat_store_dword v[77:78], v58 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v59, v95, v59                            // sum*alpha + C*beta
flat_store_dword v[79:80], v59 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v36, v96, v36                            // sum*alpha + C*beta
flat_store_dword v[81:82], v36 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v37, v97, v37                            // sum*alpha + C*beta
flat_store_dword v[83:84], v37 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v38, v98, v38                            // sum*alpha + C*beta
flat_store_dword v[85:86], v38 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v39, v99, v39                            // sum*alpha + C*beta
flat_store_dword v[87:88], v39 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v44, v100, v44                           // sum*alpha + C*beta
flat_store_dword v[89:90], v44 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v45, v101, v45                           // sum*alpha + C*beta
flat_store_dword v[91:92], v45 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(1,1,1,2); (1,1,1,3); (1,1,2,0); (1,1,2,1); (1,1,2,2); (1,1,2,3); (1,1,3,0); (1,1,3,1); (1,1,3,2) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v93, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x1, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[24:25], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
GLOBAL_OFFSET_C 77, 68, 69, 70
//v_add_u32 v77, vcc, v64, v77                       // addr = C + index*bytes (lo)
//v_addc_u32 v78, vcc, v65, v78, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v94, v[77:78]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[26:27], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
GLOBAL_OFFSET_C 79, 68, 69, 70
//v_add_u32 v79, vcc, v64, v79                       // addr = C + index*bytes (lo)
//v_addc_u32 v80, vcc, v65, v80, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v95, v[79:80]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[28:29], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
GLOBAL_OFFSET_C 81, 68, 69, 70
//v_add_u32 v81, vcc, v64, v81                       // addr = C + index*bytes (lo)
//v_addc_u32 v82, vcc, v65, v82, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v96, v[81:82]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[30:31], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
GLOBAL_OFFSET_C 83, 68, 69, 70
//v_add_u32 v83, vcc, v64, v83                       // addr = C + index*bytes (lo)
//v_addc_u32 v84, vcc, v65, v84, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v97, v[83:84]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x2, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[32:33], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
GLOBAL_OFFSET_C 85, 68, 69, 70
//v_add_u32 v85, vcc, v64, v85                       // addr = C + index*bytes (lo)
//v_addc_u32 v86, vcc, v65, v86, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v98, v[85:86]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 0, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[34:35], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
GLOBAL_OFFSET_C 87, 68, 69, 70
//v_add_u32 v87, vcc, v64, v87                       // addr = C + index*bytes (lo)
//v_addc_u32 v88, vcc, v65, v88, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v99, v[87:88]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 1, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[36:37], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
GLOBAL_OFFSET_C 89, 68, 69, 70
//v_add_u32 v89, vcc, v64, v89                       // addr = C + index*bytes (lo)
//v_addc_u32 v90, vcc, v65, v90, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v100, v[89:90]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 2, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[38:39], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
GLOBAL_OFFSET_C 91, 68, 69, 70
//v_add_u32 v91, vcc, v64, v91                       // addr = C + index*bytes (lo)
//v_addc_u32 v92, vcc, v65, v92, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v101, v[91:92]                     // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v46, s[sgprAlpha], v46                   // *= alpha
v_mul_f32 v47, s[sgprAlpha], v47                   // *= alpha
v_mul_f32 v52, s[sgprAlpha], v52                   // *= alpha
v_mul_f32 v53, s[sgprAlpha], v53                   // *= alpha
v_mul_f32 v54, s[sgprAlpha], v54                   // *= alpha
v_mul_f32 v55, s[sgprAlpha], v55                   // *= alpha
v_mul_f32 v60, s[sgprAlpha], v60                   // *= alpha
v_mul_f32 v61, s[sgprAlpha], v61                   // *= alpha
v_mul_f32 v62, s[sgprAlpha], v62                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v93, s[sgprBeta], v93                    // v93 = C*beta
v_add_f32 v46, v93, v46                            // sum*alpha + C*beta
flat_store_dword v[75:76], v46 // store C
s_mov_b64 exec, s[24:25]                           // sgprs -> exec
v_mul_f32 v94, s[sgprBeta], v94                    // v94 = C*beta
v_add_f32 v47, v94, v47                            // sum*alpha + C*beta
flat_store_dword v[77:78], v47 // store C
s_mov_b64 exec, s[26:27]                           // sgprs -> exec
v_mul_f32 v95, s[sgprBeta], v95                    // v95 = C*beta
v_add_f32 v52, v95, v52                            // sum*alpha + C*beta
flat_store_dword v[79:80], v52 // store C
s_mov_b64 exec, s[28:29]                           // sgprs -> exec
v_mul_f32 v96, s[sgprBeta], v96                    // v96 = C*beta
v_add_f32 v53, v96, v53                            // sum*alpha + C*beta
flat_store_dword v[81:82], v53 // store C
s_mov_b64 exec, s[30:31]                           // sgprs -> exec
v_mul_f32 v97, s[sgprBeta], v97                    // v97 = C*beta
v_add_f32 v54, v97, v54                            // sum*alpha + C*beta
flat_store_dword v[83:84], v54 // store C
s_mov_b64 exec, s[32:33]                           // sgprs -> exec
v_mul_f32 v98, s[sgprBeta], v98                    // v98 = C*beta
v_add_f32 v55, v98, v55                            // sum*alpha + C*beta
flat_store_dword v[85:86], v55 // store C
s_mov_b64 exec, s[34:35]                           // sgprs -> exec
v_mul_f32 v99, s[sgprBeta], v99                    // v99 = C*beta
v_add_f32 v60, v99, v60                            // sum*alpha + C*beta
flat_store_dword v[87:88], v60 // store C
s_mov_b64 exec, s[36:37]                           // sgprs -> exec
v_mul_f32 v100, s[sgprBeta], v100                  // v100 = C*beta
v_add_f32 v61, v100, v61                           // sum*alpha + C*beta
flat_store_dword v[89:90], v61 // store C
s_mov_b64 exec, s[38:39]                           // sgprs -> exec
v_mul_f32 v101, s[sgprBeta], v101                  // v101 = C*beta
v_add_f32 v62, v101, v62                           // sum*alpha + C*beta
flat_store_dword v[91:92], v62 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/******************************************/
/* Global Write Beta Edge Batch:(1,1,3,3) */
/******************************************/

/* calc coords, apply mask, and issue loads (if necessary) */
v_lshlrev_b32 v68, 6, 1                            // v68 = 1 * 64
//v_add_u32 v68, vcc, 3, v68                         // tmp0 = d0*sg0*VW + vc0
//v_add_u32 v68, vcc, v66, v68                       // coord0 += d0*sg0*VW + vc0
v_lshlrev_b32 v69, 6, 1                            // v69 = 1 * 64
//v_add_u32 v69, vcc, 0x3, v69                       // tmp1 = d1*sg1*VW + vc1
//v_add_u32 v69, vcc, v67, v69                       // coord1 += d1*sg1*VW + vc1
v_cmp_lt_u32 s[16:17], v68, v73                    // coord0 < size0
v_cmp_lt_u32 s[18:19], v69, v74                    // coord1 < size1
s_and_b64 s[22:23], s[16:17], s[18:19]             // in0 && in1
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
GLOBAL_OFFSET_C 75, 68, 69, 70
//v_add_u32 v75, vcc, v64, v75                       // addr = C + index*bytes (lo)
//v_addc_u32 v76, vcc, v65, v76, vcc                 // addr = C + index*bytes (hi)
flat_load_dword v77, v[75:76]                      // load C
s_mov_b64 exec, s[14:15]                           // full mask -> exec

/* rC *= alpha */
v_mul_f32 v63, s[sgprAlpha], v63                   // *= alpha
s_waitcnt vmcnt(0)                                 // wait C

/* apply mask, calc new C and issue write */
s_mov_b64 exec, s[22:23]                           // sgprs -> exec
v_mul_f32 v77, s[sgprBeta], v77                    // v77 = C*beta
v_add_f32 v63, v77, v63                            // sum*alpha + C*beta
flat_store_dword v[75:76], v63 // store C
s_mov_b64 exec, s[14:15]                           // full mask -> exec
s_branch label_0043                                // jump to end
label_0043:
s_endpgm                                           // End Kernel
