import { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowRight, Bell, X } from "lucide-react";
import { useAuth } from "../auth";
import { errorMessage } from "../lib/client";
import { countUnreadNotifications, createNotificationApi, notificationKeys } from "../lib/notifications";
import { useNotificationRead } from "../lib/notification-state";
import { api } from "../lib/client";
import { Button } from "./ui/button";
import { EmptyState, ErrorState, LoadingState } from "./states";

const dateFormat = new Intl.DateTimeFormat("vi-VN", {
  day: "2-digit",
  month: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});
function displayDate(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : dateFormat.format(date);
}

const backend = createNotificationApi(api);
const size = 20;

export function NotificationDropdown() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [rightOffset, setRightOffset] = useState(0);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLElement>(null);
  const panelId = useId();
  const titleId = useId();
  const read = useNotificationRead();
  const query = useQuery({
    queryKey: user ? notificationKeys.page(user.id, 0, size) : ["notifications", "anonymous", "page", 0, size],
    enabled: !!user,
    queryFn: ({ signal }) => backend.list(0, size, signal),
  });
  const unreadCount = countUnreadNotifications(query.data);
  useLayoutEffect(() => {
    if (!open) return;
    const alignToBell = () => {
      if (!trigger.current || !panel.current) return;
      const bellRight = trigger.current.getBoundingClientRect().right;
      const panelWidth = panel.current.getBoundingClientRect().width;
      // Align the right edges; shift only when the panel would cross the left viewport edge.
      setRightOffset(Math.min(0, bellRight - panelWidth - 16));
    };
    alignToBell();
    window.addEventListener("resize", alignToBell);
    return () => window.removeEventListener("resize", alignToBell);
  }, [open]);
  useEffect(() => {
    if (!open) return;
    closeButton.current?.focus();
    const onPointerDown = (event: PointerEvent) => {
      if (event.target instanceof Node && !root.current?.contains(event.target))
        setOpen(false);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        trigger.current?.focus();
      }
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);
  return (
    <div
      ref={root}
      className="relative"
      onBlur={(event) => {
        if (
          event.relatedTarget instanceof Node &&
          !event.currentTarget.contains(event.relatedTarget)
        )
          setOpen(false);
      }}
    >
      <Button
        ref={trigger}
        variant="ghost"
        className="px-2"
        aria-label={`Thông báo cá nhân${unreadCount ? `, ${unreadCount} chưa đọc` : ""}`}
        aria-expanded={open}
        aria-controls={open ? panelId : undefined}
        onClick={() => setOpen((current) => !current)}
      >
        <span className="relative inline-flex">
          <Bell className="size-5" />
          {unreadCount > 0 && <span aria-label={`${unreadCount} thông báo chưa đọc`} className="absolute -right-2 -top-2 flex min-w-4 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-bold leading-4 text-on-primary">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>}
        </span>
      </Button>
      {open && (
        <section
          ref={panel}
          id={panelId}
          role="region"
          aria-labelledby={titleId}
          style={{ right: rightOffset }}
          className="absolute top-full z-30 mt-2 w-[min(24rem,calc(100vw_-_2rem))] overflow-hidden rounded-2xl border border-border bg-surface shadow-xl"
        >
          <div className="flex items-center justify-between border-b border-border px-5 py-3">
            <div>
              <h2 id={titleId} className="font-semibold">
                Thông báo
              </h2>
            </div>
            <Button
              ref={closeButton}
              variant="ghost"
              className="px-2"
              aria-label="Đóng thông báo"
              onClick={() => {
                setOpen(false);
                trigger.current?.focus();
              }}
            >
              <X className="size-4" />
            </Button>
          </div>
          <div className="max-h-[min(24rem,60vh)] overflow-y-auto">
            {query.isPending ? (
              <LoadingState message="Đang tải thông báo…" />
            ) : query.isError ? (
              <ErrorState
                message={errorMessage(query.error)}
                onRetry={() => {
                  void query.refetch();
                }}
              />
            ) : query.data.content.length === 0 ? (
              <EmptyState
                title="Chưa có thông báo"
                message="Thông báo mới của bạn sẽ xuất hiện tại đây."
              />
            ) : (
              <ul className="divide-y divide-border/60">
                {query.data.content.slice(0, 5).map((item) => (
                  <li
                    key={item.notificationId}
                    className={`px-5 py-4 ${item.read ? "" : "bg-primary/4"}`}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={`mt-1.5 size-2 shrink-0 rounded-full ${item.read ? "bg-border" : "bg-primary"}`}
                        aria-hidden="true"
                      />
                      <div className="min-w-0 flex-1">
                        <p
                          className={`break-words text-sm ${item.read ? "font-medium" : "font-semibold"}`}
                        >
                          {item.title || "Thông báo mới"}
                        </p>
                        {item.message && (
                          <p className="mt-1 line-clamp-3 break-words text-xs leading-5 text-muted-foreground">
                            {item.message}
                          </p>
                        )}
                        <div className="mt-2 flex flex-wrap gap-2 text-[11px] text-muted-foreground">
                          {item.createdAt && displayDate(item.createdAt) && (
                            <time dateTime={item.createdAt}>
                              {displayDate(item.createdAt)}
                            </time>
                          )}
                          {!item.read && (
                            <span className="text-primary">Chưa đọc</span>
                          )}
                        </div>
                        {!item.read && (
                          <Button
                            variant="ghost"
                            className="mt-2 min-h-0 px-0 py-1 text-xs text-primary"
                            disabled={read.isPending}
                            onClick={() => { void read.markRead(item.notificationId).catch(() => undefined); }}
                          >
                            Đánh dấu đã đọc
                          </Button>
                        )}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
          {read.error && <p role="alert" className="border-t border-border px-5 py-3 text-xs text-destructive">{errorMessage(read.error)}</p>}
          <div className="border-t border-border p-2">
            <Button asChild variant="ghost" className="w-full text-primary">
              <Link to="/notifications" onClick={() => setOpen(false)}>
                Xem thêm
                <ArrowRight className="size-4" />
              </Link>
            </Button>
          </div>
        </section>
      )}
    </div>
  );
}
