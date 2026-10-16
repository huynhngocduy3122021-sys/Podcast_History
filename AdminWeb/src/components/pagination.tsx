import { ChevronLeft, ChevronRight } from 'lucide-react'
import type { PageInfo } from '../lib/pagination'
import { Button } from './ui/button'

export function Pagination({ page, pending, onPageChange }: { page: PageInfo; pending: boolean; onPageChange: (index: number) => void }) {
  const start = page.totalElements ? Math.min(page.number * page.size + 1, page.totalElements) : 0
  const end = Math.min((page.number + 1) * page.size, page.totalElements)
  return <nav aria-label="Phân trang hồ sơ" className="flex flex-wrap items-center justify-between gap-3 border-t border-border px-5 py-4">
    <p className="text-xs text-muted-foreground">{start}–{end} / {page.totalElements} hồ sơ · Trang {page.totalPages ? page.number + 1 : 0} / {page.totalPages}</p>
    <div className="flex gap-2"><Button variant="outline" aria-label="Trang trước" disabled={pending || page.number === 0} onClick={() => onPageChange(Math.max(0, page.number - 1))}><ChevronLeft className="size-4" />Trước</Button><Button variant="outline" aria-label="Trang sau" disabled={pending || page.number + 1 >= page.totalPages} onClick={() => onPageChange(page.number + 1)}>Sau<ChevronRight className="size-4" /></Button></div>
  </nav>
}
