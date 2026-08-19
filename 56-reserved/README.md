---
id: 56-reserved
title: Reserved Domain
description: Currently unassigned domain space.
aliases: [Reserved]
tags: [architecture, medinix]
---

# 56-reserved: Reserved Domain

This domain (Domain 56) is currently unassigned in the `mediNix-core` architecture. 

Previously, it housed user request services (like Jellyseerr and Bazarr), but to improve the logical separation of public-facing interfaces vs. internal backends, Jellyseerr was moved to the `55-playback` domain.

This namespace is kept open for future architectural expansion. Possible future uses for this domain:
- Dedicated Storage or ZFS pool management abstraction.
- Dedicated Identity Provider (IdP) or Single Sign-On (SSO) namespace if it grows beyond the `51-ingress` scope.
- Dedicated Machine Learning / AI media analysis processing.
