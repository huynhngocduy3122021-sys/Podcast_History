# HỢP ĐỒNG API CHO BACKEND SPRING BOOT — PHẠM VI FE2 (CREATOR STUDIO)

Tài liệu này tổng hợp toàn bộ các REST API endpoint mà Frontend (FE2 – Creator Studio) đã thiết kế và sử dụng. Backend team dựa vào tài liệu này để xây dựng Controller & Service tương ứng.

---

## 1. QUY ƯỚC CHUNG

- **Base URL:** `/api`
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
| `GET` | `/api/creator/profile` | Lấy thông tin kênh của CC | Không | `CreatorProfile` |
| `POST` | `/api/creator/register` | Nộp hồ sơ đăng ký làm Creator | `{ channelName, handle, bio, category, socialLink, sampleVoiceUrl }` | `{ status: "PENDING" }` |
| `POST` | `/api/creator/upgrade-premium` | Nâng cấp gói Studio Premium | `{ plan: "MONTHLY" }` | `{ isPremium: true }` |

### 2.2 Quản lý Podcast & Upload
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/creator/podcasts` | Danh sách podcast của kênh (có lọc `status`) | Query: `status` (DRAFT, AI_MODERATING, PENDING_ADMIN, PUBLISHED, REJECTED) | `List<CreatorPodcast>` |
| `POST` | `/api/creator/podcasts` | Tạo và đăng podcast mới | `{ title, description, eraTag, sources, isExclusive, audioUrl, coverUrl, durationSeconds }` | `CreatorPodcast` |
| `PUT` | `/api/creator/podcasts/{id}` | Cập nhật podcast | `{ title, description, eraTag, sources, isExclusive }` | `CreatorPodcast` |
| `DELETE` | `/api/creator/podcasts/{id}` | Xóa podcast | Không | `{ success: true }` |

### 2.3 Podcast theo yêu cầu (Custom Request - State Machine Escrow)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/creator/requests` | Danh sách đơn đặt podcast | Query: `status` (SENT, IN_PRODUCTION, COMPLETED, DISPUTED) | `List<PodcastRequest>` |
| `GET` | `/api/creator/requests/{id}` | Chi tiết đơn đặt, mốc và tin nhắn | Không | `PodcastRequestDetail` |
| `POST` | `/api/creator/requests/{id}/accept` | CC chấp nhận đơn đặt | Không | `{ status: "ACCEPTED" }` |
| `POST` | `/api/creator/requests/{id}/reject` | CC từ chối đơn đặt | `{ reason: "..." }` | `{ status: "REJECTED" }` |
| `POST` | `/api/creator/requests/{id}/deliver` | CC nộp bản audio hoàn chỉnh | `{ fileUrl: "...", note: "..." }` | `{ status: "DELIVERED" }` |
| `POST` | `/api/creator/requests/{id}/messages` | Gửi tin nhắn trao đổi trong đơn | `{ message: "...", attachmentUrl: "..." }` | `RequestChatMessage` |

### 2.4 Ví & Rút tiền CC (State Machine)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/creator/wallet/balance` | Xem số dư khả dụng và số dư đang giữ | Không | `WalletBalanceResponse` |
| `GET` | `/api/creator/wallet/withdrawals` | Xem lịch sử yêu cầu rút tiền | Không | `List<WithdrawalResponse>` |
| `POST` | `/api/creator/wallet/release-funds` | Giải phóng tiền chờ release vào khả dụng | Không | `{ releasedAmount: 1200000, newAvailable: 8050000 }` |
| `POST` | `/api/creator/wallet/withdrawals` | Gửi yêu cầu rút tiền và giữ số dư | `{ amount: 1000000, payoutAccountId: "..." }` | `WithdrawalResponse` |
| `GET` | `/api/creator/wallet/payout-accounts` | Xem các tài khoản nhận tiền đang hoạt động | Không | `List<PayoutAccountResponse>` |

### 2.5 Quản lý Bình luận
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/creator/comments` | Danh sách bình luận thính giả trên kênh | Không | `List<StudioComment>` |
| `PUT` | `/api/creator/comments/{id}/pin` | Bật/tắt ghim bình luận lên đầu | Không | `{ isPinned: boolean }` |
| `PUT` | `/api/creator/comments/{id}/hide` | Bật/tắt ẩn bình luận nhạy cảm | Không | `{ isHidden: boolean }` |
| `POST` | `/api/creator/comments/{id}/reply` | Trả lời bình luận với tư cách Creator | `{ replyText: "..." }` | `StudioComment` |

### 2.6 Biểu mẫu tương tác thính giả (Studio Premium)
| Method | Endpoint | Mô tả | Request Body | Response Data |
|---|---|---|---|---|
| `GET` | `/api/creator/forms` | Danh sách form khảo sát của kênh | Không | `List<InteractiveForm>` |
| `POST` | `/api/creator/forms` | Tạo form khảo sát mới | `{ title, description, questions: [...] }` | `InteractiveForm` |
