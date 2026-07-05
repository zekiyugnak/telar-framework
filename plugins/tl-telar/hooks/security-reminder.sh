#!/bin/bash
# Security reminder hook for mobile app development
# Injects security awareness during development

cat << 'EOF'

<mobile-security-awareness>
MOBILE SECURITY CHECKLIST:
- [ ] API keys not hardcoded (use environment variables)
- [ ] Sensitive data in secure storage (Keychain/Keystore)
- [ ] Certificate pinning for API calls
- [ ] No sensitive data in logs
- [ ] Biometric auth for sensitive operations
- [ ] Jailbreak/root detection for high-security apps
- [ ] Proper session management and token refresh
- [ ] Input validation on all user inputs
</mobile-security-awareness>

EOF
