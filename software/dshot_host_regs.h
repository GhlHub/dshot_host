#ifndef DSHOT_HOST_REGS_H
#define DSHOT_HOST_REGS_H

#include <stdint.h>

/*
 * DSHOT AXI-Lite host register definitions.
 *
 * Register map source of truth:
 *   rtl/dshot_axil_regs.v
 *   doc/register_map.md
 */

#define DSHOT_REG_CONTROL         0x00u
#define DSHOT_REG_STATUS          0x04u
#define DSHOT_REG_TX12            0x08u
#define DSHOT_REG_TX16            0x0Cu
#define DSHOT_REG_T0H             0x10u
#define DSHOT_REG_T1H             0x14u
#define DSHOT_REG_BIT             0x18u
#define DSHOT_REG_TURNAROUND      0x1Cu
#define DSHOT_REG_RX_SAMPLE       0x20u
#define DSHOT_REG_RX_TIMEOUT      0x24u
#define DSHOT_REG_RX_FIFO_DATA    0x28u
#define DSHOT_REG_RX_FIFO_STATUS  0x2Cu
#define DSHOT_REG_IRQ_MASK        0x30u
#define DSHOT_REG_IRQ_STATUS      0x34u
#define DSHOT_REG_IRQ_OCC         0x38u
#define DSHOT_REG_IRQ_AGE         0x3Cu
#define DSHOT_REG_RX_FIFO_TAG     0x40u

#define DSHOT_CONTROL_BIDIR_EN_MASK   (1u << 0)
#define DSHOT_CONTROL_SPEED_SHIFT     2u
#define DSHOT_CONTROL_SPEED_MASK      (0x7u << DSHOT_CONTROL_SPEED_SHIFT)

#define DSHOT_SPEED_150   0u
#define DSHOT_SPEED_300   1u
#define DSHOT_SPEED_600   2u
#define DSHOT_SPEED_1200  3u

#define DSHOT_STATUS_BUSY_MASK              (1u << 0)
#define DSHOT_STATUS_DONE_MASK              (1u << 1)
#define DSHOT_STATUS_TX_DONE_MASK           (1u << 2)
#define DSHOT_STATUS_RX_VALID_MASK          (1u << 3)
#define DSHOT_STATUS_CODE_ERROR_MASK        (1u << 4)
#define DSHOT_STATUS_RX_FIFO_OCC_SHIFT      5u
#define DSHOT_STATUS_RX_FIFO_OCC_MASK       (0x1Fu << DSHOT_STATUS_RX_FIFO_OCC_SHIFT)
#define DSHOT_STATUS_RX_FIFO_EMPTY_MASK     (1u << 10)
#define DSHOT_STATUS_RX_FIFO_FULL_MASK      (1u << 11)
#define DSHOT_STATUS_RX_FIFO_OVERFLOW_MASK  (1u << 12)
#define DSHOT_STATUS_TX_FIFO_OCC_SHIFT      13u
#define DSHOT_STATUS_TX_FIFO_OCC_MASK       (0x1Fu << DSHOT_STATUS_TX_FIFO_OCC_SHIFT)
#define DSHOT_STATUS_TX_FIFO_EMPTY_MASK     (1u << 18)
#define DSHOT_STATUS_TX_FIFO_FULL_MASK      (1u << 19)
#define DSHOT_STATUS_TX_FIFO_OVERFLOW_MASK  (1u << 20)

#define DSHOT_TX12_VALUE12_SHIFT        0u
#define DSHOT_TX12_VALUE12_MASK         (0x0FFFu << DSHOT_TX12_VALUE12_SHIFT)
#define DSHOT_TX12_REPEAT_M1_SHIFT      16u
#define DSHOT_TX12_REPEAT_M1_MASK       (0xFu << DSHOT_TX12_REPEAT_M1_SHIFT)
#define DSHOT_TX12_TAG_SHIFT            20u
#define DSHOT_TX12_TAG_MASK             (0xFu << DSHOT_TX12_TAG_SHIFT)

#define DSHOT_TX16_FRAME_SHIFT          0u
#define DSHOT_TX16_FRAME_MASK           (0xFFFFu << DSHOT_TX16_FRAME_SHIFT)
#define DSHOT_TX16_REPEAT_M1_SHIFT      16u
#define DSHOT_TX16_REPEAT_M1_MASK       (0xFu << DSHOT_TX16_REPEAT_M1_SHIFT)
#define DSHOT_TX16_TAG_SHIFT            20u
#define DSHOT_TX16_TAG_MASK             (0xFu << DSHOT_TX16_TAG_SHIFT)

#define DSHOT_RX_FIFO_STATUS_LAST_ERPM_PERIOD_SHIFT  0u
#define DSHOT_RX_FIFO_STATUS_LAST_ERPM_PERIOD_MASK   (0xFFFFu << DSHOT_RX_FIFO_STATUS_LAST_ERPM_PERIOD_SHIFT)
#define DSHOT_RX_FIFO_STATUS_OCC_SHIFT               16u
#define DSHOT_RX_FIFO_STATUS_OCC_MASK                (0x1Fu << DSHOT_RX_FIFO_STATUS_OCC_SHIFT)
#define DSHOT_RX_FIFO_STATUS_EMPTY_MASK              (1u << 21)
#define DSHOT_RX_FIFO_STATUS_FULL_MASK               (1u << 22)
#define DSHOT_RX_FIFO_STATUS_OVERFLOW_MASK           (1u << 23)

#define DSHOT_IRQ_RX_NONEMPTY_MASK   (1u << 0)
#define DSHOT_IRQ_RX_OCC_MASK        (1u << 1)
#define DSHOT_IRQ_RX_AGE_MASK        (1u << 2)
#define DSHOT_IRQ_TX_COMPLETE_MASK   (1u << 3)
#define DSHOT_IRQ_TX_EMPTY_MASK      (1u << 4)

#define DSHOT_IRQ_STATUS_AGE_SHIFT       0u
#define DSHOT_IRQ_STATUS_AGE_MASK        (0xFFFFu << DSHOT_IRQ_STATUS_AGE_SHIFT)
#define DSHOT_IRQ_STATUS_PENDING_SHIFT   16u
#define DSHOT_IRQ_STATUS_PENDING_MASK    (0x1Fu << DSHOT_IRQ_STATUS_PENDING_SHIFT)
#define DSHOT_IRQ_STATUS_SOURCE_SHIFT    21u
#define DSHOT_IRQ_STATUS_SOURCE_MASK     (0x1Fu << DSHOT_IRQ_STATUS_SOURCE_SHIFT)

#define DSHOT_RX_FIFO_TAG_RX_TAG_SHIFT          0u
#define DSHOT_RX_FIFO_TAG_RX_TAG_MASK           (0xFu << DSHOT_RX_FIFO_TAG_RX_TAG_SHIFT)
#define DSHOT_RX_FIFO_TAG_LAST_TX_DONE_SHIFT    4u
#define DSHOT_RX_FIFO_TAG_LAST_TX_DONE_MASK     (0xFu << DSHOT_RX_FIFO_TAG_LAST_TX_DONE_SHIFT)
#define DSHOT_RX_FIFO_TAG_ACTIVE_TX_SHIFT       8u
#define DSHOT_RX_FIFO_TAG_ACTIVE_TX_MASK        (0xFu << DSHOT_RX_FIFO_TAG_ACTIVE_TX_SHIFT)

#define DSHOT_PRESET_60MHZ_150_T0H         150u
#define DSHOT_PRESET_60MHZ_150_T1H         300u
#define DSHOT_PRESET_60MHZ_150_BIT         400u
#define DSHOT_PRESET_60MHZ_150_RX_SAMPLE    64u
#define DSHOT_PRESET_60MHZ_150_RX_TIMEOUT 8000u

#define DSHOT_PRESET_60MHZ_300_T0H          75u
#define DSHOT_PRESET_60MHZ_300_T1H         150u
#define DSHOT_PRESET_60MHZ_300_BIT         200u
#define DSHOT_PRESET_60MHZ_300_RX_SAMPLE    32u
#define DSHOT_PRESET_60MHZ_300_RX_TIMEOUT 4000u

#define DSHOT_PRESET_60MHZ_600_T0H          38u
#define DSHOT_PRESET_60MHZ_600_T1H          75u
#define DSHOT_PRESET_60MHZ_600_BIT         100u
#define DSHOT_PRESET_60MHZ_600_RX_SAMPLE    16u
#define DSHOT_PRESET_60MHZ_600_RX_TIMEOUT 2000u

#define DSHOT_PRESET_60MHZ_1200_T0H         19u
#define DSHOT_PRESET_60MHZ_1200_T1H         38u
#define DSHOT_PRESET_60MHZ_1200_BIT         50u
#define DSHOT_PRESET_60MHZ_1200_RX_SAMPLE    8u
#define DSHOT_PRESET_60MHZ_1200_RX_TIMEOUT 1000u

static inline uint32_t dshot_control_value(uint32_t speed, uint32_t bidir_en)
{
    return ((speed << DSHOT_CONTROL_SPEED_SHIFT) & DSHOT_CONTROL_SPEED_MASK) |
           (bidir_en ? DSHOT_CONTROL_BIDIR_EN_MASK : 0u);
}

static inline uint32_t dshot_tx12_value(uint32_t value12, uint32_t repeat_m1, uint32_t tag)
{
    return ((value12 << DSHOT_TX12_VALUE12_SHIFT) & DSHOT_TX12_VALUE12_MASK) |
           ((repeat_m1 << DSHOT_TX12_REPEAT_M1_SHIFT) & DSHOT_TX12_REPEAT_M1_MASK) |
           ((tag << DSHOT_TX12_TAG_SHIFT) & DSHOT_TX12_TAG_MASK);
}

static inline uint32_t dshot_tx16_value(uint32_t frame16, uint32_t repeat_m1, uint32_t tag)
{
    return ((frame16 << DSHOT_TX16_FRAME_SHIFT) & DSHOT_TX16_FRAME_MASK) |
           ((repeat_m1 << DSHOT_TX16_REPEAT_M1_SHIFT) & DSHOT_TX16_REPEAT_M1_MASK) |
           ((tag << DSHOT_TX16_TAG_SHIFT) & DSHOT_TX16_TAG_MASK);
}

static inline uint32_t dshot_status_rx_fifo_occupancy(uint32_t reg)
{
    return (reg & DSHOT_STATUS_RX_FIFO_OCC_MASK) >> DSHOT_STATUS_RX_FIFO_OCC_SHIFT;
}

static inline uint32_t dshot_status_tx_fifo_occupancy(uint32_t reg)
{
    return (reg & DSHOT_STATUS_TX_FIFO_OCC_MASK) >> DSHOT_STATUS_TX_FIFO_OCC_SHIFT;
}

static inline uint32_t dshot_irq_pending_bits(uint32_t reg)
{
    return (reg & DSHOT_IRQ_STATUS_PENDING_MASK) >> DSHOT_IRQ_STATUS_PENDING_SHIFT;
}

static inline uint32_t dshot_irq_source_bits(uint32_t reg)
{
    return (reg & DSHOT_IRQ_STATUS_SOURCE_MASK) >> DSHOT_IRQ_STATUS_SOURCE_SHIFT;
}

static inline uint32_t dshot_irq_fifo_age(uint32_t reg)
{
    return (reg & DSHOT_IRQ_STATUS_AGE_MASK) >> DSHOT_IRQ_STATUS_AGE_SHIFT;
}

static inline uint32_t dshot_rx_fifo_tag(uint32_t reg)
{
    return (reg & DSHOT_RX_FIFO_TAG_RX_TAG_MASK) >> DSHOT_RX_FIFO_TAG_RX_TAG_SHIFT;
}

static inline uint32_t dshot_last_tx_done_tag(uint32_t reg)
{
    return (reg & DSHOT_RX_FIFO_TAG_LAST_TX_DONE_MASK) >> DSHOT_RX_FIFO_TAG_LAST_TX_DONE_SHIFT;
}

static inline uint32_t dshot_active_tx_tag(uint32_t reg)
{
    return (reg & DSHOT_RX_FIFO_TAG_ACTIVE_TX_MASK) >> DSHOT_RX_FIFO_TAG_ACTIVE_TX_SHIFT;
}

#endif
