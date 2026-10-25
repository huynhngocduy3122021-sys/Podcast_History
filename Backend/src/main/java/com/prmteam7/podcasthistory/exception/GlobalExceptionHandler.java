package com.prmteam7.podcasthistory.exception;

import com.prmteam7.podcasthistory.dto.response.ApiError;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

@RestControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler({
    org.springframework.dao.DataIntegrityViolationException.class,
    org.springframework.orm.ObjectOptimisticLockingFailureException.class,
    org.springframework.dao.CannotAcquireLockException.class
  })
  ResponseEntity<ApiError> handleDatabaseConflict(RuntimeException exception) {
    return error(
        HttpStatus.CONFLICT,
        "Dữ liệu trùng, đã được cập nhật hoặc đang được xử lý; tải lại và thử lại.");
  }

  @ExceptionHandler({
    org.springframework.http.converter.HttpMessageNotReadableException.class,
    org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class,
    org.springframework.web.multipart.support.MissingServletRequestPartException.class
  })
  ResponseEntity<ApiError> handleInvalidRequest(Exception exception) {
    return error(HttpStatus.BAD_REQUEST, "JSON, enum, UUID hoặc file gửi lên không hợp lệ.");
  }

  @ExceptionHandler(InvalidCredentialsException.class)
  ResponseEntity<ApiError> handleInvalidCredentials(InvalidCredentialsException exception) {
    return error(HttpStatus.UNAUTHORIZED, exception.getMessage());
  }

  @ExceptionHandler(InvalidRefreshTokenException.class)
  ResponseEntity<ApiError> handleInvalidRefreshToken(InvalidRefreshTokenException exception) {
    return error(HttpStatus.UNAUTHORIZED, exception.getMessage());
  }

  @ExceptionHandler(AccountAlreadyExistsException.class)
  ResponseEntity<ApiError> handleDuplicateAccount(AccountAlreadyExistsException exception) {
    return error(HttpStatus.CONFLICT, exception.getMessage());
  }

  @ExceptionHandler(CreatorApplicationConflictException.class)
  ResponseEntity<ApiError> handleCreatorApplicationConflict(
      CreatorApplicationConflictException exception) {
    return error(HttpStatus.CONFLICT, exception.getMessage());
  }

  @ExceptionHandler(CreatorApplicationNotFoundException.class)
  ResponseEntity<ApiError> handleCreatorApplicationNotFound(
      CreatorApplicationNotFoundException exception) {
    return error(HttpStatus.NOT_FOUND, exception.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException exception) {
    String message =
        exception.getBindingResult().getFieldErrors().stream()
            .findFirst()
            .map(fieldError -> fieldError.getDefaultMessage())
            .orElse("Dữ liệu gửi lên không hợp lệ.");
    return error(HttpStatus.BAD_REQUEST, message);
  }

  @ExceptionHandler(InvalidFlowRequestException.class)
  ResponseEntity<ApiError> handleInvalidFlowRequest(InvalidFlowRequestException exception) {
    return error(HttpStatus.BAD_REQUEST, exception.getMessage());
  }

  @ExceptionHandler(InvalidMediaUploadException.class)
  ResponseEntity<ApiError> handleInvalidMediaUpload(InvalidMediaUploadException exception) {
    return error(HttpStatus.BAD_REQUEST, exception.getMessage());
  }

  @ExceptionHandler(MaxUploadSizeExceededException.class)
  ResponseEntity<ApiError> handleMaxUploadSizeExceeded(MaxUploadSizeExceededException exception) {
    return error(HttpStatus.PAYLOAD_TOO_LARGE, "Dung lượng file vượt quá giới hạn cho phép.");
  }

  @ExceptionHandler(R2NotConfiguredException.class)
  ResponseEntity<ApiError> handleR2NotConfigured(R2NotConfiguredException exception) {
    return error(HttpStatus.SERVICE_UNAVAILABLE, exception.getMessage());
  }

  @ExceptionHandler(AgoraNotConfiguredException.class)
  ResponseEntity<ApiError> handleAgoraNotConfigured(AgoraNotConfiguredException exception) {
    return error(HttpStatus.SERVICE_UNAVAILABLE, exception.getMessage());
  }

  @ExceptionHandler(R2UploadException.class)
  ResponseEntity<ApiError> handleR2Upload(R2UploadException exception) {
    return error(HttpStatus.BAD_GATEWAY, exception.getMessage());
  }

  @ExceptionHandler(MediaPlaybackException.class)
  ResponseEntity<ApiError> handleMediaPlayback(MediaPlaybackException exception) {
    return error(HttpStatus.BAD_GATEWAY, exception.getMessage());
  }

  @ExceptionHandler(ResourceNotFoundException.class)
  ResponseEntity<ApiError> handleResourceNotFound(ResourceNotFoundException exception) {
    return error(HttpStatus.NOT_FOUND, exception.getMessage());
  }

  @ExceptionHandler(ResourceForbiddenException.class)
  ResponseEntity<ApiError> handleResourceForbidden(ResourceForbiddenException exception) {
    return error(HttpStatus.FORBIDDEN, exception.getMessage());
  }

  @ExceptionHandler(ResourceConflictException.class)
  ResponseEntity<ApiError> handleResourceConflict(ResourceConflictException exception) {
    return error(HttpStatus.CONFLICT, exception.getMessage());
  }

  @ExceptionHandler(PodcastWorkflowNotFoundException.class)
  ResponseEntity<ApiError> handlePodcastWorkflowNotFound(PodcastWorkflowNotFoundException exception) {
    return error(HttpStatus.NOT_FOUND, exception.getMessage());
  }

  @ExceptionHandler(PodcastWorkflowException.class)
  ResponseEntity<ApiError> handlePodcastWorkflowConflict(PodcastWorkflowException exception) {
    return error(HttpStatus.CONFLICT, exception.getMessage());
  }

  private ResponseEntity<ApiError> error(HttpStatus status, String message) {
    return ResponseEntity.status(status)
        .body(new ApiError(Instant.now(), status.value(), status.getReasonPhrase(), message));
  }
}
