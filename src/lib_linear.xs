#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include "linear.h"

#define NO_XSLOCKS
#include "xshelper.h"

namespace {

struct parameter *
alloc_parameter(pTHX_ int num_weights) {
    struct parameter *parameter_;
    Newx(parameter_, 1, struct parameter);
    if (num_weights == 0) {
        parameter_->weight_label = NULL;
        parameter_->weight = NULL;
    } else {
        Newx(parameter_->weight_label, num_weights, int);
        Newx(parameter_->weight, num_weights, double);
    }
    parameter_->nr_weight = num_weights;
    return parameter_;
}

struct problem *
alloc_problem(pTHX_ int num_training_data) {
    struct problem *problem_;
    Newx(problem_, 1, struct problem);
    Newx(problem_->y, num_training_data, double);
    // Assuming that internal representation of null pointer is zero.
    Newxz(problem_->x, num_training_data, struct feature_node *);
    problem_->l = num_training_data;
    return problem_;
}

void
dummy_puts(const char *) {}

int
find_max_feature_index(pTHX_ AV *features) {
    int num_features = av_len(features) + 1;
    int max_feature_index = 0;
    for (int i = 0; i < num_features; ++i) {
        SV *feature = *av_fetch(features, i, 0);
        if (!(SvROK(feature) && SvTYPE(SvRV(feature)) == SVt_PVHV)) {
            Perl_croak(aTHX_ "Not a HASH reference.");
        }
        HV *feature_hash = (HV *)SvRV(feature);
        hv_iterinit(feature_hash);
        HE *nonzero_element;
        while ((nonzero_element = hv_iternext(feature_hash))) {
            I32 index_length;
            int index = atoi(hv_iterkey(nonzero_element, &index_length));
            if (max_feature_index < index) { max_feature_index = index; }
        }
    }
    return max_feature_index;
}

void
free_parameter(pTHX_ struct parameter *parameter_) {
    Safefree(parameter_->weight_label);
    Safefree(parameter_->weight);
    Safefree(parameter_);
}

void
free_problem(pTHX_ struct problem *problem_) {
    for (int i = 0; i < problem_->l; ++i) {
        struct feature_node *feature_vector = problem_->x[i];
        if (feature_vector) { Safefree(feature_vector); }
    }
    Safefree(problem_->x);
    Safefree(problem_->y);
    Safefree(problem_);
}

struct feature_node *
hv2feature(
    pTHX_ HV *feature_hash, int bias_index = 0, double bias = -1.0) {
    bool has_bias = bias >= 0;
    int feature_vector_size =
        hv_iterinit(feature_hash) + (has_bias ? 1 : 0) + 1;
    struct feature_node *feature_vector;
    Newx(feature_vector, feature_vector_size, struct feature_node);
    char *index;
    I32 index_length;
    SV *value;
    struct feature_node *curr = feature_vector;
    // XXX: Assuming that order of features doesn't matter. Right?
    while ((value = hv_iternextsv(feature_hash, &index, &index_length))) {
        curr->index = atoi(index);
        curr->value = SvNV(value);
        ++curr;
    }
    if (has_bias) {
        curr->index = bias_index;
        curr->value = bias;
        ++curr;
    }
    curr->index = -1;  // Sentinel. LIBLINEAR doesn't care about its value.
    return feature_vector;
}

}  // namespace

MODULE = Algorithm::LibLinear  PACKAGE = Algorithm::LibLinear::Model::Raw  PREFIX = ll_

BOOT:
    set_print_string_function(dummy_puts);

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
    RETVAL = load_model(filename);
    if (!RETVAL) {
        Perl_croak(aTHX_ "Failed to load a model from file: %s.", filename);
    }
OUTPUT:
    RETVAL

AV *
ll_class_labels(self)
    struct model *self;
CODE:
    RETVAL = newAV();
    av_extend(RETVAL, self->nr_class - 1);
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
    struct feature_node *feature_vector = hv2feature(aTHX_ feature_hash);
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
    struct feature_node *feature_vector = hv2feature(aTHX_ feature_hash);
    double *estimated_probabilities;
    int num_classes = get_nr_class(self);
    Newx(estimated_probabilities, num_classes, double);
    predict_probability(self, feature_vector, estimated_probabilities);
    RETVAL = newAV();
    av_extend(RETVAL, num_classes - 1);
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
    struct feature_node *feature_vector = hv2feature(aTHX_ feature_hash);
    int num_classes = get_nr_class(self);
    int num_decision_values =
      num_classes == 2 && self->param.solver_type != MCSVM_CS ? 1 : num_classes;
    double *decision_values;
    Newx(decision_values, num_decision_values, double);
    predict_values(self, feature_vector, decision_values);
    bool is_probability_model = check_probability_model(self);
    RETVAL = newAV();
    av_extend(RETVAL, num_decision_values - 1);
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

MODULE = Algorithm::LibLinear  PACKAGE = Algorithm::LibLinear::TrainingParameter  PREFIX = ll_

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
    RETVAL = alloc_parameter(aTHX_ num_weights);
    dXCPT;
    XCPT_TRY_START {
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
        // It's okay to pass NULL as 1st argument because it is never used.
        const char *message = check_parameter(NULL, RETVAL);
        if (message) {
            Perl_croak(
                aTHX_ "Training parameter is in invalid state: %s", message);
        }
    } XCPT_TRY_END
    XCPT_CATCH {
        free_parameter(aTHX_ RETVAL);
        XCPT_RETHROW;
    }
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
    av_extend(RETVAL, problem_->l - 1);
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

double
ll_cost(self)
    struct parameter *self;
CODE:
    RETVAL = self->C;
OUTPUT:
    RETVAL

double
ll_epsilon(self)
    struct parameter *self;
CODE:
    RETVAL = self->eps;
OUTPUT:
    RETVAL

double
ll_loss_sensitivity(self)
    struct parameter *self;
CODE:
    RETVAL = self->p;
OUTPUT:
    RETVAL

AV *
ll_weights(self)
    struct parameter *self;
CODE:
    RETVAL = newAV();
    av_extend(RETVAL, self->nr_weight - 1);
    for (int i = 0; i < self->nr_weight; ++i) {
        av_push(RETVAL, newSVnv(self->weight[i]));
    }
OUTPUT:
    RETVAL

AV *
ll_weight_labels(self)
    struct parameter *self;
CODE:
    RETVAL = newAV();
    av_extend(RETVAL, self->nr_weight - 1);
    for (int i = 0; i < self->nr_weight; ++i) {
        av_push(RETVAL, newSViv(self->weight_label[i]));
    }
OUTPUT:
    RETVAL

void
ll_DESTROY(self)
    struct parameter *self;
CODE:
    free_parameter(aTHX_ self);
    

MODULE = Algorithm::LibLinear  PACKAGE = Algorithm::LibLinear::Problem  PREFIX = ll_

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
    bool has_bias = bias >= 0;
    dXCPT;
    XCPT_TRY_START {
        double *labels_ = RETVAL->y;
        for (int i = 0; i < num_training_data; ++i) {
            SV *label = *av_fetch(labels, i, 0);
            labels_[i] = SvIV(label);
        }

        struct feature_node **features_ = RETVAL->x;
        int max_feature_index =
            find_max_feature_index(aTHX_ features) + (has_bias ? 1 : 0);
        for (int i = 0; i < num_training_data; ++i) {
            SV *feature = *av_fetch(features, i, 0);
            if (!(SvROK(feature) && SvTYPE(SvRV(feature)) == SVt_PVHV)) {
                Perl_croak(aTHX_ "Not a HASH reference.");
            }
            HV *feature_hash = (HV *)SvRV(feature);
            features_[i] =
                hv2feature(aTHX_ feature_hash, max_feature_index, bias);
        }
        RETVAL->bias = bias;
        RETVAL->n = max_feature_index;
    } XCPT_TRY_END
    XCPT_CATCH {
        free_problem(aTHX_ RETVAL);
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
    free_problem(aTHX_ self);
