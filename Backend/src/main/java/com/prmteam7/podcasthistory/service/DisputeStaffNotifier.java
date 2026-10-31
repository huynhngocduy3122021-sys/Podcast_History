package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.model.AppUser;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class DisputeStaffNotifier {
    private final AppUserRepository users;
    private final AdminSupportService support;

    public DisputeStaffNotifier(AppUserRepository users, AdminSupportService support) {
        this.users = users;
        this.support = support;
    }

    public void notifyOpen(String kind, UUID disputeId) {
        for (var staff : users.findAllByRole_RoleCodeAndIsActiveTrue("STAFF")) {
            support.notify(staff, "DISPUTE_ASSIGNED", "Tranh chấp cần xử lý",
                    "Có tranh chấp " + kind + " mới: " + disputeId);
        }
    }

    public void notifyCounterparty(AppUser opponent, String kind, UUID disputeId) {
        support.notify(opponent, "DISPUTE_CONFIRM_REQUIRED", "Xác nhận tranh chấp",
                "Bạn có 3 ngày để xác nhận tranh chấp " + kind + ": " + disputeId);
    }

    public void notifyConfirmed(AppUser opener, UUID disputeId) {
        support.notify(opener, "DISPUTE_CONFIRMED", "Tranh chấp đã được xác nhận",
                "Hồ sơ đã chuyển Staff: " + disputeId);
    }

    public void notifyResult(AppUser listener, AppUser creator, UUID disputeId, String result) {
        support.notify(listener, "DISPUTE_RESULT", "Kết quả tranh chấp", result + ": " + disputeId);
        support.notify(creator, "DISPUTE_RESULT", "Kết quả tranh chấp", result + ": " + disputeId);
    }
}
