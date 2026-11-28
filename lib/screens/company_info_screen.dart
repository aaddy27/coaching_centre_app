import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/ios_components.dart';

class CompanyInfoScreen extends StatelessWidget {
  const CompanyInfoScreen({super.key});

  static const String companyName = 'CIS Complete It Solution';
  static const String ownerName = 'Deepak Acharya';
  static const String mobileNumber = '9549813228';
  static const String officeAddress =
      '5-D-130, Jai Narayan Vyas Colony, Bikaner, Rajasthan';

  void _copyValue(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: value));
    showIosToast(
      context,
      title: '$label Copied',
      message: value,
      icon: CupertinoIcons.doc_on_clipboard_fill,
      iconColor: IosTheme.primaryBlue,
    );
  }

  void _shareCompanyCard(BuildContext context) {
    HapticFeedback.mediumImpact();
    const cardText = '$companyName\n'
        'Owner: $ownerName\n'
        'Mobile: +91 $mobileNumber\n'
        'Office: $officeAddress\n'
        'Mobile Apps • Web Portals • Custom Software & IT Solutions';
    Clipboard.setData(const ClipboardData(text: cardText));
    showIosToast(
      context,
      title: 'Business Card Copied',
      message: 'Company details copied! Share on WhatsApp or SMS.',
      icon: CupertinoIcons.checkmark_alt_circle_fill,
      iconColor: IosTheme.systemGreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: const IosNavBar(
        title: companyName,
        subtitle: 'IT & Software Partner',
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Promotional Brand Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: IosTheme.separator, width: 0.6),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: IosTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'CIS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IosTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OFFICIAL TECHNOLOGY PARTNER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.primaryBlue,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    companyName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: IosTheme.labelPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'End-to-end Mobile App Development, Ed-Tech Platforms, Web Applications & Complete IT Consulting in Bikaner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: IosTheme.labelTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 2. Company & Contact Information
            const IosSectionLabel('Company & Contact Details'),
            IosGroupedCard(
              children: [
                _buildInfoRow(
                  icon: CupertinoIcons.building_2_fill,
                  iconColor: IosTheme.primaryBlue,
                  label: 'Company Name',
                  value: companyName,
                  onTap: () => _copyValue(
                    context,
                    label: 'Company Name',
                    value: companyName,
                  ),
                ),
                const Divider(
                  height: 0.5,
                  indent: 60,
                  color: IosTheme.separator,
                ),
                _buildInfoRow(
                  icon: CupertinoIcons.person_crop_circle_fill,
                  iconColor: IosTheme.systemIndigo,
                  label: 'Owner',
                  value: ownerName,
                  onTap: () => _copyValue(
                    context,
                    label: 'Owner Name',
                    value: ownerName,
                  ),
                ),
                const Divider(
                  height: 0.5,
                  indent: 60,
                  color: IosTheme.separator,
                ),
                _buildInfoRow(
                  icon: CupertinoIcons.phone_fill,
                  iconColor: IosTheme.systemGreen,
                  label: 'Mobile Number',
                  value: '+91 $mobileNumber',
                  trailingHint: 'Tap to copy',
                  onTap: () => _copyValue(
                    context,
                    label: 'Mobile Number',
                    value: mobileNumber,
                  ),
                ),
                const Divider(
                  height: 0.5,
                  indent: 60,
                  color: IosTheme.separator,
                ),
                _buildInfoRow(
                  icon: CupertinoIcons.location_solid,
                  iconColor: IosTheme.systemOrange,
                  label: 'Office Address',
                  value: officeAddress,
                  trailingHint: 'Tap to copy',
                  onTap: () => _copyValue(
                    context,
                    label: 'Office Address',
                    value: officeAddress,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 3. Services Offered (Ad Showcase)
            const IosSectionLabel('Our Services'),
            IosGroupedCard(
              children: [
                _buildServiceRow(
                  icon: CupertinoIcons.device_phone_portrait,
                  iconColor: IosTheme.primaryBlue,
                  title: 'iOS & Android Mobile Apps',
                  subtitle: 'Native-grade Flutter & custom business apps',
                ),
                const Divider(
                  height: 0.5,
                  indent: 60,
                  color: IosTheme.separator,
                ),
                _buildServiceRow(
                  icon: CupertinoIcons.globe,
                  iconColor: IosTheme.systemIndigo,
                  title: 'Web Portals & Ed-Tech Systems',
                  subtitle: 'LMS, test series platforms, APIs & admin panels',
                ),
                const Divider(
                  height: 0.5,
                  indent: 60,
                  color: IosTheme.separator,
                ),
                _buildServiceRow(
                  icon: CupertinoIcons.desktopcomputer,
                  iconColor: IosTheme.systemGreen,
                  title: 'Complete IT & Software Solutions',
                  subtitle: 'Billing, ERP, cloud setup & technical support',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. Primary Actions
            IosPrimaryButton(
              label: 'Copy Mobile • $mobileNumber',
              icon: CupertinoIcons.phone_fill,
              onPressed: () => _copyValue(
                context,
                label: 'Mobile Number',
                value: mobileNumber,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                onPressed: () => _shareCompanyCard(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.share,
                      color: IosTheme.primaryBlue,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Share Business Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.primaryBlue,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? trailingHint,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: IosTheme.labelTertiary,
                          ),
                        ),
                        if (trailingHint != null) ...[
                          const Spacer(),
                          Text(
                            trailingHint,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: IosTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.labelPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: IosTheme.labelPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: IosTheme.labelTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
