package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.PaymentMethod;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentMethodRepository extends JpaRepository<PaymentMethod, UUID> {

    Optional<PaymentMethod> findFirstByPayment_PaymentIdAndMethodCodeIgnoreCase(
            UUID paymentId, String methodCode);
}
