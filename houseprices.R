setwd("C:/Users/OEM/OneDrive/Desktop/R/house_prices")
houseprices <- readr::read_csv("train.csv")
summary(houseprices)

library(tidyverse)
library(tidymodels)
library(caret)
library(corrplot)
library(gridExtra)
library(ggcorrplot)
library(mgcv)
theme_set(theme_bw())


## Identifying categories in indicator variables

house <- houseprices %>% 
  mutate(MSSubClass = as.factor(MSSubClass),
         MSZoning = as.factor(MSZoning),
         Street = as.factor(Street),
         Alley = as.factor(Alley),
         LotShape = as.factor(LotShape),
         LandContour = as.factor(LandContour),
         Utilities = as.factor(Utilities),
         LotConfig = as.factor(LotConfig),
         LandSlope = as.factor(LandSlope),
         Neighborhood = as.factor(Neighborhood),
         Condition1 = as.factor(Condition1),
         Condition2 = as.factor(Condition2),
         BldgType = as.factor(BldgType),
         HouseStyle = as.factor(HouseStyle),
         OverallQual = as.factor(OverallQual),
         OverallCond = as.factor(OverallCond),
         RoofStyle = as.factor(RoofStyle),
         RoofMatl = as.factor(RoofMatl),
         Exterior1st = as.factor(Exterior1st),
         Exterior2nd = as.factor(Exterior2nd),
         MasVnrType = as.factor(MasVnrType),
         ExterQual = as.factor(ExterQual),
         ExterCond = as.factor(ExterCond),
         Foundation = as.factor(Foundation),
         BsmtQual = as.factor(BsmtQual),
         BsmtCond = as.factor(BsmtCond),
         BsmtExposure = as.factor(BsmtExposure),
         BsmtFinType1 = as.factor(BsmtFinType1),
         BsmtFinType2 = as.factor(BsmtFinType2),
         Heating = as.factor(Heating),
         HeatingQC = as.factor(HeatingQC),
         CentralAir = as.factor(CentralAir),
         Electrical = as.factor(Electrical),
         KitchenQual = as.factor(KitchenQual),
         Functional = as.factor(Functional),
         FireplaceQu = as.factor(FireplaceQu),
         GarageType = as.factor(GarageType),
         GarageFinish = as.factor(GarageFinish),
         GarageQual = as.factor(GarageQual),
         GarageCond = as.factor(GarageCond),
         PavedDrive = as.factor(PavedDrive),
         PoolQC = as.factor(PoolQC),
         Fence = as.factor(Fence),
         MiscFeature = as.factor(MiscFeature),
         MoSold = as.factor(MoSold),
         YrSold = as.factor(YrSold),
         SaleType = as.factor(SaleType),
         SaleCondition = as.factor(SaleCondition))

## For LotFrontage we can substitute the NA's for the mean value

house$LotFrontage[is.na(house$LotFrontage)] <- round(mean(house$LotFrontage, na.rm=TRUE))
summary(house$LotFrontage)

## For some variables the NA means None

na_to_none <- function(variables) {
  variable_char <- as.character(variables)
  variable_char[is.na(variable_char)] <- "None"
  variable_fac <- as.factor(variable_char)
  
  return(variable_fac)
}

factor_list <- c("Alley","BsmtQual", "BsmtCond", "BsmtExposure", "BsmtFinType1", 
                 "BsmtFinType2", "Electrical", "FireplaceQu",
                 "GarageType","GarageFinish","GarageQual","GarageCond","PoolQC",
                 "Fence","MiscFeature")

for (i in factor_list) {
  house[[i]] <- na_to_none(house[[i]])
}
summary(house)


colnames(house)[colSums(is.na(house)) > 0]

## For GarageYrBlt I assume a NA means No garage but we can visualize it 
garage <- house %>% 
  select(GarageType, GarageYrBlt)
  
DT::datatable(filter(garage, garage$GarageType == "None"))
str(house$GarageYrBlt)

house$GarageYrBlt[is.na(house$GarageYrBlt)] <- 0

## For MasVnrType we can do substitute the Na's by nones and for the area by 0's
house$MasVnrType[is.na(house$MasVnrType)] <- "None"
summary(house$MasVnrType)

house$MasVnrArea[is.na(house$MasVnrArea)] <- 0

## Now the dataset has no more NA's. We can proceed to EDA.

hist(house$SalePrice, breaks = 200) # There are some houses that were sold for more than $650,000
sum(house$SalePrice > 650000) # Two houses. We can drop these outliers
boxplot(house$SalePrice)

hist(house$LotArea, breaks = 100) # Are these big houses the expensive ones?
DT::datatable(filter(house, house$SalePrice > 650000)) # Yes, they are.


sl1 <- house %>% 
  ggplot(aes(LotArea, SalePrice))+
  geom_point(alpha = 0.3) +
  geom_smooth(method = "gam")+
  labs(subtitle = "Complete sample")

sl2 <- house %>% 
  filter(SalePrice < 650000 & LotArea < 20000) %>% 
  ggplot(aes(LotArea, SalePrice))+
  geom_point(alpha = 0.3) +
  geom_smooth(method = "gam")+
  labs(subtitle = "Subsetting with price < $650,000 and lot area < 20000 sqrft")
  
grid.arrange(sl1, sl2)

## If we consider the complete sample, the model will not capture the effects correctly.
## As we can see, the data is more concentrated to the left. In this subsample, the effects
## are non-linear. It is an important feature to consider when fitting a regression.

# Lets investigate the effects of different zones. 
plot(house$MSZoning) ## This seems like a problem
table(house$MSZoning) ## C and RH are less than 20 observations. There is not enough data for the zones.

## Area
zone <- house %>% 
  ggplot(aes(SalePrice, fill = MSZoning)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Zone")

neighborhood <- plot(house$Neighborhood)
neighborhood <- house %>% 
  ggplot(aes(SalePrice, fill = Neighborhood)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Neighborhood")

grid.arrange(zone, neighborhood)
## Both seem to affect the saleprice

## Features of the house
msssubclass <- house %>% 
  ggplot(aes(SalePrice, fill = MSSubClass)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Type of dwelling involved in the sale")

## Houses built in 1946 and newer(Groups: 20, 60, 120) were sold at a higher price than older.
## Among those, 2-story houses(60) are the more expensive. 

lotshape <- house %>% 
  ggplot(aes(SalePrice, fill = LotShape)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Lot Shape")

condition1 <- house %>% 
  ggplot(aes(SalePrice, fill = Condition1)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Condition 1")
condition2 <- house %>% 
  ggplot(aes(SalePrice, fill = Condition2)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Condition 2")


housestyle <- house %>% 
  ggplot(aes(SalePrice, fill = HouseStyle)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Style of dwelling")

grid.arrange(lotshape, condition1, condition2, housestyle) # Graph features
## Lot Shape seems to not affect the saleprice

overallqual <- house %>% 
  ggplot(aes(SalePrice, fill = OverallQual)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Rates the overall material and finish of the house")
  

overallcond <- house %>% 
  ggplot(aes(SalePrice, fill = OverallCond)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Rates the overall condition of the house")

extercond <- house %>% 
  ggplot(aes(SalePrice, fill = ExterCond)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Evaluates the present condition of the material on the exterior")

grid.arrange(overallqual, overallcond, extercond) # Condition of the house
#The median values of ExterCond seem equal.

baths <- house %>% 
  ggplot(aes(SalePrice, fill = as.factor(FullBath))) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Number of full bathrooms")

bedroom <- house %>% 
  ggplot(aes(SalePrice, fill = as.factor(BedroomAbvGr))) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip()+
  labs(subtitle = "Bedrooms above grade")
  
garagety <- house %>% 
  ggplot(aes(SalePrice, fill = GarageType)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip()+
  labs(subtitle = "Garage type")

pool <- house %>% 
  ggplot(aes(SalePrice, fill = PoolQC)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Pool quality")

grid.arrange(baths, bedroom, garagety, pool) #Features 2 in the house

yrsold <- house %>% 
  ggplot(aes(SalePrice, fill = YrSold)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() 
  
mosold <- house %>% 
  ggplot(aes(SalePrice, fill = MoSold)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip()

salecond <- house %>% 
  ggplot(aes(SalePrice, fill = SaleCondition)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Condition of sale")

grid.arrange(yrsold, mosold, salecond) # Conditions at the moment of sale
## All matter, special attention to Baths.

heating <- house %>% 
  ggplot(aes(SalePrice, fill = Heating)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Heating")

heatingQual <- house %>% 
  ggplot(aes(SalePrice, fill = HeatingQC)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Heating Quality")

centralair <- house %>% 
  ggplot(aes(SalePrice, fill = CentralAir)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Central Air")

electricalsystem <- house %>% 
  ggplot(aes(SalePrice, fill = Electrical)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Electrical system")

foundation <- house %>% 
  ggplot(aes(SalePrice, fill = Foundation)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Foundation")

landcontour <- house %>% 
  ggplot(aes(SalePrice, fill = LandContour)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Land Contour")

garagecars <- house %>% 
  ggplot(aes(SalePrice, fill = as.factor(GarageCars))) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Garage Cars")

fence <- house %>% 
  ggplot(aes(SalePrice, fill = Fence)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Fence")

miscfeature <- house %>% 
  ggplot(aes(SalePrice, fill = MiscFeature)) +
  geom_boxplot(outlier.alpha =0.5) +
  coord_flip() +
  labs(subtitle = "Miscellaneous feature not covered in other categories")

grid.arrange(heating, heatingQual, centralair, electricalsystem, foundation, landcontour, garagecars,
             fence, miscfeature)

house %>% 
  filter(SalePrice < 650000 & LotArea < 20000) %>% 
  ggplot(aes(SalePrice,YearBuilt)) +
  geom_point() +
  geom_smooth(method = "gam")+
  coord_flip()

# Plotting the correlation of SalePrice with the numerical variables

house$stFlrSF <- house$`1stFlrSF`
house$ndFlrSF <- house$`2ndFlrSF`
house$SsnPorch <- house$`3SsnPorch`

num_house <- house %>% 
  select(LotFrontage,  LotArea,  YearBuilt,  YearRemodAdd,  MasVnrArea,  BsmtFinSF1, BsmtFinSF2, BsmtUnfSF,  TotalBsmtSF,  stFlrSF,  ndFlrSF,  LowQualFinSF,  GrLivArea,  BsmtFullBath,  BsmtHalfBath, FullBath,  HalfBath,  BedroomAbvGr,  KitchenAbvGr,  TotRmsAbvGrd,  Fireplaces,  GarageYrBlt,  GarageCars,  GarageArea,  WoodDeckSF,  OpenPorchSF,  EnclosedPorch, SsnPorch,  ScreenPorch,  PoolArea,  MiscVal)
saleprice <- house$SalePrice
num_house <- as.data.frame(num_house)

corrhouse <- cor(saleprice, num_house)
corrhouse <- as.data.frame(corrhouse)

ggcorrplot(as.data.frame(as.matrix(corrhouse)), lab =TRUE, lab_size = 2.5,
           title = "Correlation Sale Price vs other numerical")

# Only Garage Area, Garage Cars, Fireplaces, TotRmsAbvGr, Full Bath, GrLiveArea, stFlrSf, TotalBsmtSf
# And maybe YearRemodAdd and YearBuilt might be considered for analysis7
# We could also add  all Halfbath and Bath together to get a better perspective of bathrooms.

house <- house %>% 
  mutate(Baths = 0.5*(HalfBath) + FullBath + 0.5*(BsmtHalfBath) + BsmtFullBath)

cor(house$SalePrice, house$Baths)
# Baths look good.

## Adding variables that seems to affect SalePrice
house_ready <- house %>% 
  select(-LotShape, -MiscVal, -PoolArea, -ScreenPorch, - SsnPorch, -EnclosedPorch, -OpenPorchSF,
         -WoodDeckSF, -GarageYrBlt, -KitchenAbvGr, -BedroomAbvGr, -LowQualFinSF, -ndFlrSF,
         -BsmtUnfSF, -BsmtFinSF2, -HalfBath, -FullBath, -BsmtHalfBath, -BsmtFullBath, -`1stFlrSF`, 
         `2ndFlrSF`, -Condition2, -OverallCond, -RoofMatl, -Exterior1st, -Exterior2nd)

summary(house_ready)
linear1 <- lm(SalePrice~. - Id, data = house_ready)


house_ready$predict <- predict(linear1)
house_ready %>% 
  ggplot(aes(predict, SalePrice)) +
  geom_point()
# The model looks good using only data that it has seen. Now lets try splitting the data set


set.seed(1234)
house_split <- house_ready %>% 
  initial_split(strata = Utilities)
house_train <- training(house_split)
house_test <- testing(house_split)

linear2 <- lm(SalePrice~. - Id - Street - CentralAir, data = house_train)

predict_trainlm <- predict(linear2)
house_train %>% 
  ggplot(aes(predict, SalePrice)) +
  geom_point() +
  geom_smooth()

# Still good
# RMSE?
rmse <- function(actual,predicted) {
  error = actual - predicted
  se = error^2
  mse = mean(se)
  rmse = sqrt(mse)
  return(rmse)
}


rmse(house_train$SalePrice, house_train$predict)
rmsle(house_train$SalePrice, house_train$predict)

predict_testlm <- predict(linear2, newdata = house_test)
house_test %>% 
  ggplot(aes(predict, SalePrice)) +
  geom_point() +
  geom_smooth()

rmse(house_test$SalePrice, house_test$predict)
rmsle(house_test$SalePrice, house_test$predict)

## Now lets fit an additive model
df1 <- c("MSZoning", "Neighborhood", "MSSubClass", "Condition1", "HouseStyle", "OverallQual",
         "ExterCond", "GarageType", "PoolQC", "YrSold", "MoSold", "SaleCondition", 
         "Fireplaces", "GarageCars", "Baths")
df2 <- c("YearBuilt", "LotFrontage", "LotArea", "YearBuilt", "YearRemodAdd", "MasVnrArea", "BsmtFinSF1", 
          "TotalBsmtSF", "stFlrSF","GrLivArea", 
         "TotRmsAbvGrd", "GarageArea")

var1 <- paste(df1, collapse=" + ")
var2 <- paste('s(', df2[-1], ')', sep = "", collapse = ' + ')

fm <- as.formula(paste("SalePrice ~", var1, "+", var2))
spline1 <- gam(fm, data = house_train)
house_train$predict_trainspline <- predict(spline1)

house_test$predict_testspline <- predict(spline1, newdata = house_test)
rmse(house_train$SalePrice,house_train$predict_trainspline)
house_train %>% 
  ggplot(aes(predict_trainspline, SalePrice)) +
  geom_point() +
  geom_smooth()

house_test <- house_test %>%
  filter(house_test$predict_testspline >=0)

rmse(house_test$SalePrice,house_test$predict_testspline)
house_test %>% 
  ggplot(aes(predict_testspline, SalePrice)) +
  geom_point() +
  geom_smooth()

rmsle(house_train$SalePrice, house_train$predict_trainspline)
rmsle(house_test$SalePrice, house_test$predict_testspline)

## Random Forest
rf_spec <- rand_forest(mode = "regression") %>% 
  set_engine("ranger")

rf_spec

rf_fit <- rf_spec %>% 
  fit(SalePrice~. - Id, data = house_train)

rf_fit
house_train$predict_rf <- predict(rf_fit, new_data = house_train)

result_train <- rf_fit %>% 
  predict(new_data = house_train) %>% 
  mutate(actual = house_train$SalePrice)

result_train %>% 
  ggplot(aes(.pred, actual))+
  geom_point()
rmse(result_train$actual, result_train$.pred)
rmsle(result_train$actual, result_train$.pred)

result_test <- rf_fit %>% 
  predict(new_data = house_test) %>% 
  mutate(actual = house_test$SalePrice)
result_test %>% 
  ggplot(aes(.pred, actual))+
  geom_point()
rmse(result_test$actual, result_test$.pred)
rmsle(result_test$actual, result_test$.pred)

### RMSE for tets too high. Lets use cv
house_train <- training(house_split)
house_test <- testing(house_split)

house_folds <- vfold_cv(house_train, strata = Utilities) # This divides our house_train in 10 parts

rf_res <- fit_resamples(
  rf_spec, #The specification
  SalePrice ~ . - Id,
  house_folds, #Resamples
  control = control_resamples(save_pred = TRUE) #To fine tune the resampling process
)

rf_res %>% 
  collect_metrics()

rf_res %>% 
  unnest(.predictions) %>% 
  ggplot(aes(SalePrice, .pred, color = id)) +
  geom_abline(lty = 2, color = "black", size = 1) +
  geom_point(alpha = 0.5)

lm_spec <- linear_reg () %>% 
  set_engine( engine ="lm")

lm_spec

lm_fit <- lm_spec %>% 
  fit(SalePrice ~ . -Id,
      data = house_train)
lm_fit 

lm_res <- fit_resamples(
  lm_spec, #The specification
  SalePrice ~ . -Id,
  house_folds, #Resamples
  control = control_resamples(save_pred = TRUE) #To fine tune the resampling process
)

lm_res %>% 
  collect_metrics()
lm_res %>% 
  unnest(.predictions) %>% 
  ggplot(aes(SalePrice, .pred, color = id)) +
  geom_abline(lty = 2, color = "black", size = 1) +
  geom_point(alpha = 0.5)

#############################################################
#xgBoost
library(caret)
library(plyr)
library(xgboost)
library(Metrics)
house_train <- training(house_split)
house_test <- testing(house_split)

control = trainControl(method = "cv",  # cross validation
                       number = 10)     # 5-folds


# Create grid of tuning parameters
grid = expand.grid(nrounds=c(100, 200, 400),     # 3 different amounts of boosting rounds
                   max_depth= c(4, 6),           # 2 values for tree depth
                   eta=c(0.1, 0.05, 0.025),      # 3 values for learning rate
                   gamma= c(0.1), 
                   colsample_bytree = c(1), 
                   min_child_weight = c(1),
                   subsample=0.7)

set.seed(1234)
xgb =  train(SalePrice~. - Id,      
             data=house_train,
             method="xgbTree",
             trControl=control, 
             tuneGrid=grid,
             maximize = FALSE)

xgb$results
xgb$bestTune
varImp(xgb)

house_train$predict_boost <- predict(xgb, new_data = house_train)
test_predictions = predict(xgb, newdata=house_test)
house_test$predict_boost <- test_predictions

rmse(house_train$SalePrice, house_train$predict_boost)
rmse(house_test$SalePrice, house_test$predict_boost)
rmsle(house_train$SalePrice, house_train$predict_boost)
rmsle(house_test$SalePrice, house_test$predict_boost)




