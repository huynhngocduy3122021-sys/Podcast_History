// Keep this in sync with CREATOR_PLANS_ENABLED and MEMBERSHIPS_ENABLED on the backend.
const bool kPackagesEnabled = bool.fromEnvironment('PACKAGES_ENABLED', defaultValue: false);
