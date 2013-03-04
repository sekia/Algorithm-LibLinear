#include <algorithm>
#include <cerrno>
#include <cstring>
#include "linear.h"

#define NO_XSLOCKS
#include "xshelper.h"

static struct parameter *
alloc_parameter(pTHX_ int num_weights) {
    struct parameter *parameter_;
    Newx(parameter_, 1, struct parameter);
    Newx(parameter_->weight_label, num_weights, int);
    Newx(parameter_->weight, num_weights, double);
    parameter_->nr_weight = num_weights;
    return parameter_;
}

static struct problem *
alloc_problem(pTHX_ int num_training_data) {
    struct problem *problem_;
    Newx(problem_, 1, struct problem);
    Newx(problem_->y, num_training_data, double);
    // Assuming that internal representation of null pointer is zero.
    Newxz(problem_->x, num_training_data, struct feature_node *);
    problem_->l = num_training_data;
    return problem_;
}

static void
free_parameter(pTHX_ struct parameter *parameter_) {
    Safefree(parameter_->weight_label);
    Safefree(parameter_->weight);
    Safefree(parameter_);
}

static void
free_problem(pTHX_ struct problem *problem_) {
    for (int i = 0; i < problem_->l; ++i) {
        struct feature_node *feature_vector = problem_->x[i];
        if (feature_vector) { Safefree(feature_vector); }
    }
    Safefree(problem_->x);
    Safefree(problem_->y);
    Safefree(problem_);
}

static struct feature_node *
HV2feature(pTHX_ HV *feature_hash) {
    int feature_vector_size = hv_iterinit(feature_hash) + 1;
    struct feature_node *feature_vector;
    Newx(
      feature_vector,
      feature_vector_size,
      struct feature_node);
    HE *nonzero_element;
    struct feature_node *curr = feature_vector;
    while (nonzero_element = hv_iternext(feature_hash)) {
        SV *index = HeSVKEY_force(nonzero_element);
        SV *value = HeVAL(nonzero_element);
        curr->index = SvIV(index);
        curr->value = SvNV(value);
        ++curr;
    }
    curr->index = -1;  // Sentinel. LIBLINEAR doesn't care about its value.
}

MODULE = Algorithm::LinearSVM  PACKAGE = Algorithm::LinearSVM::Model::Raw  PREFIX = ll_

PROTOTYPES: DISABLE

struct model *
ll_train(klass, problem_, parameter_)
    const char *klass;
    struct problem *problem_;
    struct parameter *parameter_;
CODE:
    RETVAL = train(problem_, parameter_);
OUTPUT:
    RETVAL

struct model *
ll_load(klass, filename)
    const char *klass;
    const char *filename;
CODE:
    load_model(filename);

AV *
ll_class_labels(self)
    struct model *self;
CODE:
    RETVAL = newAV();
    for (int i = 0; i < self->nr_class; ++i) {
        av_push(RETVAL, newSViv(self->label[i]));
    }
OUTPUT:
    RETVAL

bool
ll_is_probability_model(self)
    struct model *self;
CODE:
    RETVAL = check_probability_model(self);
OUTPUT:
    RETVAL

int
ll_num_classes(self)
    struct model *self;
CODE:
    RETVAL = get_nr_class(self);
OUTPUT:
    RETVAL

int
ll_num_features(self)
    struct model *self;
CODE:
    RETVAL = get_nr_feature(self);
OUTPUT:
    RETVAL

SV *
ll_predict(self, feature_hash)
    struct model *self;
    HV *feature_hash;
CODE:
    struct feature_node *feature_vector = HV2feature(aTHX_ feature_hash);
    double prediction = predict(self, feature_vector);
    Safefree(feature_vector);
    RETVAL = check_probability_model(self) ?
      newSVnv(prediction) : newSViv((int)prediction);
OUTPUT:
    RETVAL

AV *
ll_predict_probability(self, feature_hash)
    struct model *self;
    HV *feature_hash;
CODE:
    struct feature_node *feature_vector = HV2feature(aTHX_ feature_hash);
    double *estimated_probabilities;
    int num_classes = get_nr_class(self);
    Newx(estimated_probabilities, num_classes, double);
    predict_probability(self, feature_vector, estimated_probabilities);
    RETVAL = newAV();
    for (int i = 0; i < num_classes; ++i) {
        av_push(RETVAL, newSVnv(estimated_probabilities[i]));
    }
    Safefree(feature_vector);
    Safefree(estimated_probabilities);
OUTPUT:
    RETVAL

AV *
ll_predict_values(self, feature_hash)
    struct model *self;
    HV *feature_hash;
CODE:
    struct feature_node *feature_vector = HV2feature(aTHX_ feature_hash);
    int num_classes = get_nr_class(self);
    int num_decision_values =
      num_classes == 2 && self->param.solver_type != MCSVM_CS ? 1 : num_classes;
    double *decision_values;
    Newx(decision_values, num_decision_values, double);
    predict_values(self, feature_vector, decision_values);
    bool is_probability_model = check_probability_model(self);
    RETVAL = newAV();
    for (int i = 0; i < num_decision_values; ++i) {
        SV *decision_value = is_probability_model ?
          newSVnv(decision_values[i]) : newSViv((int)decision_values[i]);
        av_push(RETVAL, decision_value);
    }
    Safefree(decision_values);
    Safefree(feature_vector);
OUTPUT:
    RETVAL

void
ll_save(self, filename)
    struct model *self;
    const char *filename;
CODE:
    if (save_model(filename, self) != 0) {
        Perl_croak(
          aTHX_
          "Error occured during save process: %s",
          errno == 0 ? "unknown error" : strerror(errno)
        );
    }

void
ll_DESTROY(self)
    struct model *self;
CODE:
    free_and_destroy_model(&self);

MODULE = Algorithm::LinearSVM  PACKAGE = Algorithm::LinearSVM::Parameter  PREFIX = ll_

PROTOTYPES: DISABLE

struct parameter *
ll_new(klass, solver_type, epsilon, cost, weight_labels, weights, loss_sensitivity)
    const char *klass;
    int solver_type;
    double epsilon;
    double cost;
    AV *weight_labels;
    AV *weights;
    double loss_sensitivity;
CODE:
    int num_weights = av_len(weight_labels) + 1;
    if (av_len(weights) + 1 != num_weights) {
        Perl_croak(
          aTHX_
          "The number of weight labels is not equal to the number of"
          " weights.");
    }
    RETVAL = alloc_parameter(num_weights);
    RETVAL->solver_type = solver_type;
    RETVAL->eps = epsilon;
    RETVAL->C = cost;
    int *weight_labels_ = RETVAL->weight_label;
    double *weights_ = RETVAL->weight;
    for (int i = 0; i < num_weights; ++i) {
        weight_labels_[i] = SvIV(*av_fetch(weight_labels, i, 0));
        weights_[i] = SvNV(*av_fetch(weights, i, 0));
    }
    RETVAL->p = loss_sensitivity;
OUTPUT:
    RETVAL

AV *
ll_cross_validation(self, problem_, num_folds)
    struct parameter *self;
    struct problem *problem_;
    int num_folds;
CODE:
    double *targets;
    Newx(targets, problem_->l, double);
    cross_validation(problem_, self, num_folds, targets);
    RETVAL = newAV();
    for (int i = 0; i < problem_->l; ++i) {
        av_push(RETVAL, newSVnv(targets[i]));
    }
    Safefree(targets);
OUTPUT:
    RETVAL

bool
ll_is_regression_solver(self)
    struct parameter *self;
CODE:
    RETVAL =
      self->solver_type == L2R_L2LOSS_SVR
      || self->solver_type == L2R_L1LOSS_SVR_DUAL
      || self->solver_type == L2R_L2LOSS_SVR_DUAL;
OUTPUT:
    RETVAL

void
ll_DESTROY(self)
    struct parameter *self;
CODE:
    free_parameter(self);
    

MODULE = Algorithm::LinearSVM  PACKAGE = Algorithm::LinearSVM::Problem  PREFIX = ll_

PROTOTYPES: DISABLE

struct problem *
ll_new(klass, labels, features, bias = -1)
    const char *klass;
    AV *labels;
    AV *features;
    double bias;
  CODE:
    int num_training_data = av_len(labels) + 1;
    if (num_training_data == 0) {
        Perl_croak(aTHX_ "No training set is given.");
    }
    if (av_len(features) + 1 != num_training_data) {
        Perl_croak(
            aTHX_
            "The number of labels is not equal to the number of features.");
    }

    RETVAL = alloc_problem(aTHX_ num_training_data);
    dXCPT;
    XCPT_TRY_START {
        double *labels_ = RETVAL->y;
        struct feature_node **features_ = RETVAL->x;
        int max_feature_index = 0;
        for (int i = 0; i < num_training_data; ++i) {
            SV *label = *av_fetch(labels, i, 0);
            labels_[i] = SvIV(label);
    
            SV *feature = *av_fetch(features, i, 0);
            if (!(SvROK(feature) && SvTYPE(SvRV(feature)) == SVt_PVHV)) {
                Perl_croak(aTHX_ "Not a HASH reference.");
            }
            HV *feature_hash = (HV *)SvRV(feature);
            int feature_vector_size = hv_iterinit(feature_hash) + 1;
            struct feature_node *feature_vector;
            Newx(
              feature_vector,
              feature_vector_size,
              struct feature_node);
            HE *nonzero_element;
            struct feature_node *curr = feature_vector;
            while (nonzero_element = hv_iternext(feature_hash)) {
                SV *index = HeSVKEY_force(nonzero_element);
                SV *value = HeVAL(nonzero_element);
                curr->index = SvIV(index);
                curr->value = SvNV(value);
                max_feature_index = std::max(max_feature_index, curr->index);
                ++curr;
            }
            // Sentinel. LIBLINEAR doesn't care about its value.
            curr->index = -1;
            features_[i] = feature_vector;
        }
        RETVAL->bias = bias;
        RETVAL->n = bias < 0 ? max_feature_index : max_feature_index + 1;
    } XCPT_TRY_END
    XCPT_CATCH {
        free_problem(RETVAL);
        XCPT_RETHROW;
    }
  OUTPUT:
    RETVAL

double
ll_bias(self)
    struct problem *self;
  CODE:
    RETVAL = self->bias;
  OUTPUT:
    RETVAL

int
ll_data_set_size(self)
    struct problem *self;
  CODE:
    RETVAL = self->l;
  OUTPUT:
    RETVAL

int
ll_num_features(self)
    struct problem *self;
  CODE:
    RETVAL = self->n;
  OUTPUT:
    RETVAL

void
ll_DESTROY(self)
    struct problem *self;
  CODE:
    free_problem(self);
