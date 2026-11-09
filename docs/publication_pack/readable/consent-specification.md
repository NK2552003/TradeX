# Cookie Consent Notice and Deployment Specification

Release resource | Updated 2026-11-09

This reference describes the cookie choices provided by Alphajournal and the controls an optional integration must follow.

## Initial notice

Essential storage supports sign-in, security and your choices. Optional tracking is your decision. Closing the notice does not accept it. Google AdSense is planned for the free version and is not active in this release. Change your choices any time in Help and policies. The available actions are Accept optional, Reject optional, Manage choices and Read cookie policy.

## Granular controls

The settings view keeps essential storage on and offers independent analytics, advertising and affiliate switches. Personalised ads additionally require advertising; turning advertising off also turns personalisation off. Save choices records the current selection. Accept optional enables all four optional purposes; Reject optional disables them. These choices are separate from service terms, marketing emails and device permissions.

## Persistence and renewal

A versioned record stores the UTC time and categories in SharedPreferences. It is valid for 180 days. Missing, corrupt, future-dated, expired or different-version records resolve to optional purposes off. Clearing site storage resets this preference. Another browser or device has its own choices. The record contains no advertising visitor ID and is not a contract-acceptance record.

## Withdrawal and failures

Reopen preferences from Help and policies, Privacy settings or available footer links. Rejection removes first-party automatic referral identifiers. If persistence fails, show a clear error, keep optional activity off and provide retry or essential-only continuation. Do not imply that a failed save succeeded. Withdrawal applies to future optional activity and cannot recall information already transmitted.

## Integrations and regional consent

An optional SDK must wait for the relevant choice and stop future requests after withdrawal. No AdSense script is active in this release. Before enabling Google advertising, the required publisher configuration and regional consent controls must be in place. The local preference screen is not a Google-certified CMP and does not create an IAB TCF consent string. It must not be used as a substitute where a certified CMP is required.

## Accessibility and review

Accept and reject actions have comparable prominence. Controls must remain reachable with keyboard navigation, screen readers, mobile widths and enlarged text. Verify fresh visits, reload, granular choices, rejection, withdrawal, expiry, blocked storage and network traffic. Contact h82292245@gmail.com to report a control that does not behave as described.
