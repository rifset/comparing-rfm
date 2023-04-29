library(data.table)
library(tidyverse)

rfm_table <- fread("rfm_table.csv")
glimpse(rfm_table)

# overview

recency_dist <- rfm_table %>% 
  ggplot(aes(x = recency)) +
  geom_histogram(
    aes(y = ..density..), 
    bins = 50,
    fill = "steelblue",
    alpha = .5
  ) +
  geom_density(
    linewidth = 1,
    lty = 2
  ) +
  labs(title = "Distribution of Recency") +
  theme_bw()

frequency_dist <- rfm_table %>% 
  ggplot(aes(x = frequency)) +
  geom_histogram(
    aes(y = ..density..), 
    bins = 50,
    fill = "magenta",
    alpha = .5
  ) +
  geom_density(
    linewidth = 1,
    lty = 2
  ) +
  labs(title = "Distribution of Frequency") +
  theme_bw()

monetary_dist <- rfm_table %>% 
  ggplot(aes(x = monetary_value)) +
  geom_histogram(
    aes(y = ..density..), 
    bins = 50,
    fill = "darkgreen",
    alpha = .5
  ) +
  geom_density(
    linewidth = 1,
    lty = 2
  ) +
  labs(title = "Distribution of Monetary") +
  theme_bw()

gridExtra::grid.arrange(
  recency_dist,
  frequency_dist,
  monetary_dist,
  nrow = 2,
  ncol = 2,
  layout_matrix = rbind(c(1,1, 2,2), c(NA, 3, 3, NA)),
  top = grid::textGrob(
    "Distribution of RFM variables", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  )
)

gridExtra::grid.arrange(
  recency_dist + scale_x_log10(),
  frequency_dist + scale_x_log10(),
  monetary_dist + scale_x_log10(),
  nrow = 2,
  ncol = 2,
  layout_matrix = rbind(c(1,1, 2,2), c(NA, 3, 3, NA)),
  top = grid::textGrob(
    "Distribution of RFM variables (log10 transform)", 
    gp = grid::gpar(fontsize = 16, fontface = "bold", col = "darkblue")
  )
)


# quantile split

rfm_quantile_threshold <- rfm_table %>% 
  summarize(across(-store_number, ~quantile(., c(0:4)/4))) %>% 
  mutate(quantile = scales::percent(c(0:4)/4), .before = 1)

gridExtra::grid.arrange(
  gridExtra::tableGrob(
    rfm_quantile_threshold,
    rows = NULL
  ),
  nrow = 1,
  top = grid::textGrob(
    "Quantile values", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  )
)

rfm_quantized <- rfm_table %>% 
  mutate(across(
    .cols = -store_number,
    .fns = function(x) {
      cut(
        x = x, 
        breaks = c(-Inf, quantile(x, c(.25, .5, .75, 1))),
        labels = if(cur_column() == "recency") {c(1:4)} else {c(4:1)}
      )
    },
    .names = "{.col}_quantile"
  ))
rfm_quantized

rfm_quantized_scored <- rfm_quantized %>% 
  mutate(across(ends_with("quantile"), ~parse_number(as.character(.)))) %>% 
  rowwise() %>% 
  mutate(score = sum(recency_quantile, frequency_quantile, monetary_value_quantile)/3) %>% 
  mutate(
    tier = case_when(
      score == 1 ~ "T1 Champion",
      score > 1 & score < 2 ~ "T2 High",
      score >= 2 & score < 3 ~ "T3 Medium",
      TRUE ~ "T4 Low"
    )
  )

summary_quantized <- rfm_quantized_scored %>% 
  group_by(tier) %>% 
  summarize(
    N = uniqueN(store_number),
    total_purchase = sum(frequency),
    total_spent = sum(monetary_value)
  ) %>% 
  mutate(
    avg_purchase = total_purchase/N,
    avg_spent = total_spent/N,
    `% N` = N/sum(N),
    `% purchase` = total_purchase/sum(total_purchase),
    `% spent` = total_spent/sum(total_spent)
  )


# K-means
library(factoextra)
set.seed(2204)

kmeans_feature <- rfm_table %>% 
  column_to_rownames("store_number") %>% 
  mutate(monetary_value = log10(monetary_value)) %>% 
  scale()

kmeans_wss <- fviz_nbclust(kmeans_feature, kmeans, "wss")
kmeans_sil <- fviz_nbclust(kmeans_feature, kmeans, "sil")

gridExtra::grid.arrange(
  kmeans_wss,
  kmeans_sil,
  nrow = 1,
  top = grid::textGrob(
    "Determining cluster size", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  )
)

kmeans_model <- kmeans(kmeans_feature, center = 4L, iter.max = 1e3, nstart = 30L)
rfm_kmeans <- rfm_table %>% 
  cbind(cluster = kmeans_model$cluster)
rfm_kmeans

rfm_kmeans %>% 
  group_by(cluster) %>% 
  summarize(across(recency:monetary_value, mean)) %>% 
  arrange(desc(monetary_value))

kmeans_cluster_tier <- data.table(
  cluster = c(1, 3, 4, 2),
  tier = c("T1 Champion", "T2 High", "T3 Medium", "T4 Low")
)

gridExtra::grid.arrange(
  gridExtra::tableGrob(
    rfm_kmeans %>% 
      group_by(cluster) %>% 
      summarize(across(recency:monetary_value, mean)) %>% 
      arrange(desc(monetary_value)) %>% 
      round(2),
    rows = NULL
  ),
  gridExtra::tableGrob(
    kmeans_cluster_tier,
    rows = NULL
  ),
  nrow = 1,
  top = grid::textGrob(
    "K-Means clustering results", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  ),
  layout_matrix = rbind(c(1, 1, 2))
)

summary_kmeans <- rfm_kmeans %>% 
  inner_join(kmeans_cluster_tier, by = "cluster") %>% 
  group_by(tier) %>% 
  summarize(
    N = uniqueN(store_number),
    total_purchase = sum(frequency),
    total_spent = sum(monetary_value)
  ) %>% 
  mutate(
    avg_purchase = total_purchase/N,
    avg_spent = total_spent/N,
    `% N` = N/sum(N),
    `% purchase` = total_purchase/sum(total_purchase),
    `% spent` = total_spent/sum(total_spent)
  )


# Head/Tail breaks

source("HT_breaks.R")

recency_breaks <- HT_breaks(rfm_table$recency, 4)
recency_breaks
frequency_breaks <- HT_breaks(rfm_table$frequency, 4)
frequency_breaks
monetary_breaks <- HT_breaks(rfm_table$monetary_value, 4)
monetary_breaks

rfm_HT_threshold <- data.table(
  threshold = c(0:4),
  recency = recency_breaks$bin,
  frequency = frequency_breaks$bin,
  monetary = monetary_breaks$bin
)

gridExtra::grid.arrange(
  gridExtra::tableGrob(
    rfm_HT_threshold %>% 
      round(2),
    rows = NULL
  ),
  nrow = 1,
  top = grid::textGrob(
    "Head/tail breaks bin values", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  )
)

rfm_HT <- rfm_table %>% 
  mutate(
    recency_HT = cut(
      x = recency,
      breaks = recency_breaks$bin,
      labels = c(1:4)
    ),
    frequency_HT = cut(
      x = frequency,
      breaks = frequency_breaks$bin,
      labels = c(4:1)
    ),
    monetary_HT = cut(
      x = monetary_value,
      breaks = monetary_breaks$bin,
      labels = c(4:1)
    )
  )
rfm_HT

rfm_HT_scored <- rfm_HT %>% 
  mutate(across(ends_with("HT"), ~parse_number(as.character(.)))) %>% 
  rowwise() %>% 
  mutate(score = sum(recency_HT, frequency_HT, monetary_HT)/3) %>% 
  mutate(
    tier = case_when(
      score == 1 ~ "T1 Champion",
      score > 1 & score < 2 ~ "T2 High",
      score >= 2 & score < 3 ~ "T3 Medium",
      TRUE ~ "T4 Low"
    )
  )
rfm_HT_scored %>% 
  as.data.table()

summary_HT <- rfm_HT_scored %>% 
  group_by(tier) %>% 
  summarize(
    N = uniqueN(store_number),
    total_purchase = sum(frequency),
    total_spent = sum(monetary_value)
  ) %>% 
  mutate(
    avg_purchase = total_purchase/N,
    avg_spent = total_spent/N,
    `% N` = N/sum(N),
    `% purchase` = total_purchase/sum(total_purchase),
    `% spent` = total_spent/sum(total_spent)
  )

# check all
list(
  quantile = summary_quantized,
  kmeans = summary_kmeans,
  headtail = summary_HT
)

gridExtra::grid.arrange(
  ggplot() +
    annotation_custom(
      gridExtra::tableGrob(
        summary_quantized %>% 
          mutate(across(starts_with("%"), ~scales::percent(., .1))) %>% 
          mutate(across(starts_with("avg"), ~round(., 2))),
        rows = NULL
      )
    ) +
    labs(title = "Quantile Split Method") +
    theme_void() +
    theme(plot.margin = margin(0, 0.03, 0.01, 0.03, unit = "npc")),
  ggplot() +
    annotation_custom(
      gridExtra::tableGrob(
        summary_kmeans %>% 
          mutate(across(starts_with("%"), ~scales::percent(., .1))) %>% 
          mutate(across(starts_with("avg"), ~round(., 2))),
        rows = NULL
      )
    ) +
    labs(title = "K-Means Clustering Method") +
    theme_void() +
    theme(plot.margin = margin(0, 0.03, 0.01, 0.03, unit = "npc")),
  ggplot() +
    annotation_custom(
      gridExtra::tableGrob(
        summary_HT %>% 
          mutate(across(starts_with("%"), ~scales::percent(., .1))) %>% 
          mutate(across(starts_with("avg"), ~round(., 2))),
        rows = NULL
      )
    ) +
    labs(title = "Head/tail Breaks Method") +
    theme_void() +
    theme(plot.margin = margin(0, 0.03, 0.01, 0.03, unit = "npc")),
  ncol = 1,
  top = grid::textGrob(
    "Comparison Summary", 
    gp = grid::gpar(fontsize = 16, fontface = "bold")
  )
)
