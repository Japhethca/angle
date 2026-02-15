export { SettingsLayout } from "./components/settings-layout";
export { AccountForm } from "./components/account-form";
export { ProfileImageSection } from "./components/profile-image-section";
export { VerificationSection } from "./components/verification-section";
export { QuickSignInSection } from "./components/quick-sign-in-section";
export { StoreForm } from "./components/store-form";
export { StoreLogoSection } from "./components/store-logo-section";
export { StoreVerificationSection } from "./components/store-verification-section";
export { ChangePasswordForm } from "./components/change-password-form";
export { TwoFactorSection } from "./components/two-factor-section";
export { AutoChargeSection } from "./components/auto-charge-section";
export { PaymentMethodsSection } from "./components/payment-methods-section";
export { PayoutMethodsSection } from "./components/payout-methods-section";
export { PreferencesForm } from "./components/preferences-form";
export { NotificationSection } from "./components/notification-section";
export { LegalContent } from "./components/legal-content";

export interface SettingsUser {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  location: string | null;
}

export interface StoreProfileData {
  id: string;
  store_name: string;
  contact_phone: string | null;
  whatsapp_link: string | null;
  location: string | null;
  address: string | null;
  delivery_preference: string | null;
}
