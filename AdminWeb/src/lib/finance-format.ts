const decimalPattern = /^-?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))$/

export function formatMoney(value: string | null | undefined, currency: string) {
  if (value === null || value === undefined || String(value).trim() === '') return '—'

  const raw = String(value).trim()
  if (!decimalPattern.test(raw)) return `${raw} ${currency}`

  const negative = raw.startsWith('-')
  const unsigned = negative ? raw.slice(1) : raw
  const [integerPart, fractionalPart] = unsigned.split('.')
  const integer = integerPart.replace(/^0+(?=\d)/, '')
  const groupedInteger = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')

  try {
    const formatter = new Intl.NumberFormat('vi-VN', {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    })
    const parts = formatter.formatToParts(negative ? -0 : 0)
    const decimalSeparator = new Intl.NumberFormat('vi-VN').formatToParts(1.1)
      .find(part => part.type === 'decimal')?.value || ','
    return parts.map(part => {
      if (part.type === 'integer') {
        return `${groupedInteger}${fractionalPart !== undefined ? `${decimalSeparator}${fractionalPart}` : ''}`
      }
      if (part.type === 'group' || part.type === 'fraction') return ''
      return part.value
    }).join('') || `${negative ? '-' : ''}${groupedInteger}${fractionalPart ? `${decimalSeparator}${fractionalPart}` : ''} ${currency}`
  } catch {
    return `${negative ? '-' : ''}${groupedInteger}${fractionalPart ? `.${fractionalPart}` : ''} ${currency}`
  }
}

export function formatDate(value: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('vi-VN', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

export function statusLabel(status: string) {
  const labels: Record<string, string> = {
    PENDING: 'Chờ xử lý', PROCESSING: 'Đang xử lý', COMPLETED: 'Đã hoàn tất', FAILED: 'Thất bại',
    REJECTED: 'Đã từ chối', REFUNDED: 'Đã hoàn tiền', PAID: 'Đã thu', SUCCESS: 'Thành công',
    ACTIVE: 'Đang hoạt động', INACTIVE: 'Ngừng hoạt động', OPEN: 'Đang mở', RESOLVED: 'Đã giải quyết',
    DISPUTED: 'Đang tranh chấp', CANCELLED: 'Đã hủy', IN_PROGRESS: 'Đang xử lý', ACCEPTED: 'Đã chấp nhận',
    SIGNED: 'Đã ký', CREATED: 'Đã tạo',
  }
  return labels[status] || status
}

export function statusClass(status: string) {
  const tone = ['COMPLETED', 'PAID', 'ACTIVE'].includes(status)
    ? 'bg-success/10 text-success'
    : ['FAILED', 'REJECTED', 'REFUNDED', 'INACTIVE'].includes(status)
      ? 'bg-destructive/10 text-destructive'
      : ''
  return `${tone} status-${status.toLowerCase()}`.trim()
}
