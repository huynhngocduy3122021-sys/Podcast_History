package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.repository.AppUserRepository;
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
}
