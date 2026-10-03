package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import com.prmteam7.podcasthistory.entity.BaseEntity;
import com.prmteam7.podcasthistory.entity.UpdatedEntity;
import java.util.UUID;

@Entity
@Table(name = "role", uniqueConstraints = {
        @UniqueConstraint(name = "uk_role_role_code", columnNames = {"role_code"})
    })
public class Role extends BaseEntity {
    @Id
    @Column(name = "role_id", nullable = false, updatable = false)
    private UUID roleId;

    @Column(name = "role_code", nullable = false, length = 30)
    private String roleCode;

    @Column(name = "role_name", nullable = false, length = 80)
    private String roleName;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    public Role() {
    }

    @PrePersist
    private void assignId() {
        if (roleId == null) {
            roleId = UUID.randomUUID();
        }
    }

    public UUID getRoleId() {
        return roleId;
    }

    public void setRoleId(UUID roleId) {
        this.roleId = roleId;
    }

    public String getRoleCode() {
        return roleCode;
    }

    public void setRoleCode(String roleCode) {
        this.roleCode = roleCode;
    }

    public String getRoleName() {
        return roleName;
    }

    public void setRoleName(String roleName) {
        this.roleName = roleName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

}
