import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for Layout & Navigation components (Tabs, Accordion, Breadcrumbs, Pagination, Stepper).
class LayoutNavigationExampleView extends StatefulWidget {
  const LayoutNavigationExampleView({super.key});

  @override
  State<LayoutNavigationExampleView> createState() => _LayoutNavigationExampleViewState();
}

class _LayoutNavigationExampleViewState extends State<LayoutNavigationExampleView> {
  int _currentPage = 0;
  int _currentStep = 1;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Breadcrumbs', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiBreadcrumbs(
            crumbs: <UiCrumb>[
              UiCrumb(label: 'Workspace'),
              UiCrumb(label: 'Journal'),
              UiCrumb(label: 'NVDA Long Position'),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Accordion Collapse Panels', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiAccordion(
            items: <UiAccordionItem>[
              UiAccordionItem(
                title: 'Risk Management Guidelines',
                content: Text('Maximum 2% portfolio risk per individual trade setup. Cut losses at predetermined stop-loss.'),
              ),
              UiAccordionItem(
                title: 'Execution Checklists',
                content: Text('Verify daily volume, key resistance levels, market trend alignment, and earnings calendar.'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Stepper Navigation', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiStepper(
            steps: const <UiStepperStep>[
              UiStepperStep(title: 'Setup', subtitle: 'Identify trade criteria'),
              UiStepperStep(title: 'Sizing', subtitle: 'Calculate risk & share count'),
              UiStepperStep(title: 'Execution', subtitle: 'Place limit order'),
            ],
            currentIndex: _currentStep,
            onStepTap: (step) => setState(() => _currentStep = step),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Pagination', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiPagination(
            page: _currentPage,
            pageCount: 12,
            onPageChanged: (page) => setState(() => _currentPage = page),
          ),
        ],
      ),
    );
  }
}
