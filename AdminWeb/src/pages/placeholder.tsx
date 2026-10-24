import { Construction, ArrowLeft } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '../components/ui/button'

export function PlaceholderPage({ title }: { title: string }) {
  return <><p className="eyebrow">Không gian quản trị</p><h1 className="mt-2 text-3xl font-bold">{title}</h1><section className="panel mt-8 flex min-h-80 flex-col items-center justify-center p-8 text-center"><div className="mb-5 rounded-2xl bg-muted p-4"><Construction className="size-8 text-bronze" /></div><span className="badge mb-4">Placeholder · Phase 1</span><h2 className="text-xl font-semibold">Nền tảng đã sẵn sàng</h2><p className="mt-3 max-w-lg text-sm leading-6 text-muted-foreground">Trang này chưa triển khai dữ liệu và thao tác nghiệp vụ. Các bước xem, xử lý và xác nhận sẽ được xây dựng trong giai đoạn tiếp theo theo hợp đồng Backend.</p><Button asChild variant="outline" className="mt-6"><Link to="/dashboard"><ArrowLeft className="size-4" />Về tổng quan</Link></Button></section></>
}
export function NotFoundPage() {
  return <section className="state-panel"><h1 className="text-2xl font-bold">404 · Trang không tồn tại</h1><Button asChild><Link to="/dashboard">Về tổng quan</Link></Button></section>
}
