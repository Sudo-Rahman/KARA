# Autonomous widget refresh

The timeline provider must fetch market data itself. A `.after(30 minutes)` timeline that merely reads the host snapshot will repeatedly display the same data when iOS does not run the host's `BGAppRefreshTask`. Background App Refresh remains supplementary.

Widget extensions cannot use the host's App Attest transport. After an authenticated bootstrap GET, the backend issues an opaque, random read-only widget grant in `X-Kara-Widget-Token`. The app stores it with its API origin in its existing app-group container, protected until first unlock. Subsequent host bootstraps reuse the grant. Redis stores only its SHA-256 digest and attested owner; each successful use renews its 90-day inactivity expiration. It is accepted exclusively by `GET /widget/v1/quotes.json`; all existing `/v1/` routes still require App Attest. No additional server secret is needed.

Every timeline refresh reads the shared state, fetches the four EUR quotes plus any required purchase currencies (USD, CHF, GBP), and revalues anonymous holdings locally. No holdings are sent to the backend. The source's timestamps remain authoritative, including weekends and network failures. Market data has its own cache with a 15-minute reuse interval; coordinated merge/write prevents overlapping timelines from replacing newer quotes with older ones. The extension rereads the host snapshot after networking so a concurrent privacy or inventory change wins. It never writes the host's snapshot.

Old schema-v1 snapshots remain readable. Valuation inputs and coverage are optional additions. Masking removes them; missing host quotes do not discard otherwise valid holdings.

## Rollout

1. Deploy the backend containing the grant provisioning and widget quotes route, using the existing Redis service (Redis 6.2+ for GETEX).
2. Ship the updated app and embedded widget extension.
3. Open the updated app once with a successful market bootstrap to provision the grant and publish valuation inputs. This is required for migration; subsequent timeline fetches do not require the app process. An expired/lost grant needs a new successful host bootstrap.

The code change does not deploy the server or publish an App Store build.

## Verification

Automated Apple tests cover two-day-old snapshots without host writes, offline fallback, anonymous EUR/foreign-currency valuation, incomplete inputs, privacy changing during a request, concurrent refresh completion, legacy decoding, widget HTTP authentication/decoding, and host-to-widget grant provisioning. Backend tests cover authenticated grant issuance, rejection, read-only endpoint scope and unchanged source dates.

On a physical device with the deployed backend and new build: open the app once, install market and portfolio widgets, record displayed source dates/values, leave the app unopened and do not tap the widgets for 48 hours across trading hours. Check that later WidgetKit timelines show changed source quotes and recalculated portfolio values. A simulator test cannot certify iOS's real-world scheduling budget. The 30-minute policy requests an opportunity; iOS controls its timing.

References: [Apple widget freshness](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [networking in a widget](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension), [App Attest extension support](https://developer.apple.com/documentation/DeviceCheck/establishing-your-app-s-integrity).
