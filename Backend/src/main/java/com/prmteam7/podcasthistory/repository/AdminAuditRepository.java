package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.AdminAudit;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface AdminAuditRepository
    extends JpaRepository<AdminAudit, UUID>, JpaSpecificationExecutor<AdminAudit> {}
