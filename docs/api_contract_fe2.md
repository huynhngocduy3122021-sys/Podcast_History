# HỢP ĐỒNG API CHO BACKEND SPRING BOOT — PHẠM VI FE2 (CREATOR STUDIO)

Tài liệu này tổng hợp toàn bộ các REST API endpoint mà Frontend (FE2 – Creator Studio) đã thiết kế và sử dụng. Backend team dựa vào tài liệu này để xây dựng Controller & Service tương ứng.

---

## 1. QUY ƯỚC CHUNG

- **Base URL:** `/api/v1`
- **Header xác thực:** `Authorization: Bearer <accessToken>`
- **Đơn vị tiền tệ:** Số nguyên VND (`Integer` / `Long`), ví dụ `1500000` (không dùng double).
- **Định dạng thời gian:** Chuỗi ISO-8601 UTC (`yyyy-MM-dd'T'HH:mm:ss'Z'`).
- **Response Format chuẩn:**
```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "meta": { "page": 1, "size": 20, "total": 100 }
}
```

---

## 2. DANH SÁCH ENDPOINT CHI TIẾT

### 2.1 Hồ sơ Creator & Đăng ký làm CC
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/profile` | Lấy thông tin kênh của CC | Không | `CreatorProfile` |
| `POST` | `/api/v1/creator/register` | Nộp hồ sơ đăng ký làm Creator | `{ channelName, handle, bio, category, socialLink, sampleVoiceUrl }` | `{ status: "PENDING" }` |
| `POST` | `/api/v1/creator/upgrade-premium` | Nâng cấp gói Studio Premium | `{ plan: "MONTHLY" }` | `{ isPremium: true }` |

### 2.2 Quản lý Podcast & Upload
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/podcasts` | Danh sách podcast của kênh (có lọc `status`) | Query: `status` (DRAFT, AI_MODERATING, PENDING_ADMIN, PUBLISHED, REJECTED) | `List<CreatorPodcast>` |
| `POST` | `/api/v1/creator/podcasts` | Tạo và đăng podcast mới | `{ title, description, eraTag, sources, isExclusive, audioUrl, coverUrl, durationSeconds }` | `CreatorPodcast` |
| `PUT` | `/api/v1/creator/podcasts/{id}` | Cập nhật podcast | `{ title, description, eraTag, sources, isExclusive }` | `CreatorPodcast` |
| `DELETE` | `/api/v1/creator/podcasts/{id}` | Xóa podcast | Không | `{ success: true }` |

### 2.3 Podcast theo yêu cầu (Custom Request - State Machine Escrow)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/requests` | Danh sách đơn đặt podcast | Query: `status` (SENT, IN_PRODUCTION, COMPLETED, DISPUTED) | `List<PodcastRequest>` |
| `GET` | `/api/v1/creator/requests/{id}` | Chi tiết đơn đặt, mốc và tin nhắn | Không | `PodcastRequestDetail` |
| `POST` | `/api/v1/creator/requests/{id}/accept` | CC chấp nhận đơn đặt | Không | `{ status: "ACCEPTED" }` |
| `POST` | `/api/v1/creator/requests/{id}/reject` | CC từ chối đơn đặt | `{ reason: "..." }` | `{ status: "REJECTED" }` |
| `POST` | `/api/v1/creator/requests/{id}/deliver` | CC nộp bản audio hoàn chỉnh | `{ fileUrl: "...", note: "..." }` | `{ status: "DELIVERED" }` |
| `POST` | `/api/v1/creator/requests/{id}/messages` | Gửi tin nhắn trao đổi trong đơn | `{ message: "...", attachmentUrl: "..." }` | `RequestChatMessage` |

### 2.4 Ví & Rút tiền CC (State Machine)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/wallet` | Số dư ví: Khả dụng, Chờ release, Đang giữ, Đã rút | Không | `{ available: 6850000, pending: 1200000, holding: 1500000, totalWithdrawn: 8500000 }` |
| `GET` | `/api/v1/creator/wallet/transactions` | Lịch sử giao dịch ví | Query: `type`, `page`, `size` | `List<WalletTransaction>` |
| `POST` | `/api/v1/creator/wallet/release-funds` | Giải phóng tiền chờ release vào khả dụng | Không | `{ releasedAmount: 1200000, newAvailable: 8050000 }` |
| `POST` | `/api/v1/creator/wallet/withdraw` | Gửi yêu cầu rút tiền về ngân hàng | `{ amount: 1000000, bankAccountId: "...", pin: "123456" }` | `WalletTransaction (status: PROCESSING)` |
| `GET` | `/api/v1/creator/bank-accounts` | Danh sách tài khoản ngân hàng thụ hưởng | Không | `List<BankAccount>` |
| `POST` | `/api/v1/creator/bank-accounts` | Thêm tài khoản ngân hàng mới | `{ bankName, accountNumber, accountHolder }` | `BankAccount` |
| `DELETE` | `/api/v1/creator/bank-accounts/{id}` | Xóa tài khoản ngân hàng | Không | `{ success: true }` |

### 2.5 Quản lý Bình luận
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/comments` | Danh sách bình luận thính giả trên kênh | Không | `List<StudioComment>` |
| `PUT` | `/api/v1/creator/comments/{id}/pin` | Bật/tắt ghim bình luận lên đầu | Không | `{ isPinned: boolean }` |
| `PUT` | `/api/v1/creator/comments/{id}/hide` | Bật/tắt ẩn bình luận nhạy cảm | Không | `{ isHidden: boolean }` |
| `POST` | `/api/v1/creator/comments/{id}/reply` | Trả lời bình luận với tư cách Creator | `{ replyText: "..." }` | `StudioComment` |

### 2.6 Biểu mẫu tương tác thính giả (Studio Premium)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/v1/creator/forms` | Danh sách form khảo sát của kênh | Không | `List<InteractiveForm>` |
| `POST` | `/api/v1/creator/forms` | Tạo form khảo sát mới | `{ title, description, questions: [...] }` | `InteractiveForm` |
