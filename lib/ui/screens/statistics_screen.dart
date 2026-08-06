import 'package:appintern/ui/controllers/statistics_controller.dart';
import 'package:appintern/core/theme/app_colors.dart';
import 'package:appintern/ui/widgets/statistics/ai_insight_card_widget.dart';
import 'package:appintern/ui/widgets/statistics/burn_rate_progress_widget.dart';
import 'package:appintern/ui/widgets/statistics/donut_chart_widget.dart';
import 'package:appintern/ui/widgets/statistics/category_analysis_widget.dart';
import 'package:appintern/ui/widgets/statistics/income_expense_bar_chart_widget.dart';
import 'package:appintern/ui/widgets/statistics/trend_area_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class StatisticsScreen extends GetView<StatisticsController> {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Thống kê',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Obx(() {
            if (controller.isInitialLoading.value) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: _buildSkeletonLoading(),
              );
            }

            // Check if we have absolutely no expense data across any chart
            final noExpense =
                (controller.donutChartData['totalExpense'] ?? 0) == 0;
            if (noExpense && controller.burnRateData.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: _buildEmptyState(),
              );
            }

            final isOffline = controller.isOffline;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                children: [
                  // Burn Rate Progress
                  BurnRateProgressWidget(burnRateData: controller.burnRateData),
                  SizedBox(height: 16.h),

                  // AI Insight
                  AiInsightCardWidget(
                    insightText: controller.aiInsight.value,
                    isOffline: isOffline,
                  ),
                  SizedBox(height: 16.h),

                  // Bar Chart (Thu vs Chi)
                  const IncomeExpenseBarChartWidget(),
                  SizedBox(height: 16.h),

                  // Donut Chart
                  const DonutChartWidget(),
                  SizedBox(height: 16.h),

                  // Category Analysis (New Inline)
                  Obx(
                    () => controller.selectedAnalysisCategoryId.value.isNotEmpty
                        ? Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: const CategoryAnalysisWidget(),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Trend Area Chart
                  const TrendAreaChartWidget(),
                  SizedBox(height: 32.h), // Bottom padding
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.3, end: 0.7),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  height: index == 0 ? 150.h : 250.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              );
            },
            onEnd: () {
              // Not infinitely looping easily, but provides initial visual indicator
            },
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400.h,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 80.r,
            color: AppColors.gray200,
          ),
          SizedBox(height: 16.h),
          Text(
            'Chưa có dữ liệu.\nHãy tạo giao dịch đầu tiên của bạn!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
