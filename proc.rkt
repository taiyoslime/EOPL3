#lang eopl

(define identifier? symbol?)

; env

(define empty-env
    (lambda ()
        (lambda (search-var)
            (report-no-binding-found search-var))))

(define extend-env
    (lambda (saved-var saved-val saved-env) 
        (lambda (search-var)
            (if (eqv? search-var saved-var) 
            saved-val
            (apply-env saved-env search-var)))))

(define apply-env
    (lambda (env search-var) 
        (env search-var)))

(define report-no-binding-found 
    (lambda (search-var)
        (eopl:error 'apply-env "No binding for ~s" search-var)))


; lexer & parser

(define lexical-spec
    '((whitespace (whitespace) skip)
        (comment ("%" (arbno (not #\newline))) skip)
        (identifier
            (letter (arbno (or letter digit "_" "-" "?")))
            symbol)
        (number (digit (arbno digit)) number)
        (number ("-" digit (arbno digit)) number)
        ))
            
(define grammar
    '((program (expression) a-program)
        (expression (number) const-exp)
        (expression
            ("-" "(" expression "," expression ")")
            diff-exp)
        (expression
            ("zero?" "(" expression ")")
            zero?-exp)
        (expression
            ("if" expression "then" expression "else" expression)
            if-exp)
        (expression (identifier) var-exp)
        (expression
            ("let" identifier "=" expression "in" expression)
            let-exp)
        
        (expression
            ("proc" "(" identifier ")" expression)
            proc-exp)
            
        (expression
            ("(" expression expression ")")
            call-exp)
        ))

(sllgen:make-define-datatypes lexical-spec grammar)
#|
(define-datatype expression expression? 
    (const-exp
        (num number?)) 
    (diff-exp
        (exp1 expression?)
        (exp2 expression?))
    (zero?-exp
        (exp1 expression?))
    (if-exp
        (exp1 expression?)
        (exp2 expression?)
        (exp3 expression?))
    (var-exp
        (var identifier?))
    (let-exp
        (var identifier?)
        (exp1 expression?)
        (body expression?))
    (proc-exp
        (var identifier?)
        (body expression?))
    (call-exp
        (rator expression?)
        (rand expression?))


(define-datatype program program? (a-program
        (exp1 expression?)))
|#

(define scan&parse
    (sllgen:make-string-parser lexical-spec grammar))

; val

(define proc? procedure?)

(define procedure
    (lambda (var body env)
        (lambda (val)
            (value-of body (extend-env var val env)))))

(define apply-procedure
    (lambda (proc val)
        (proc val)))


(define-datatype expval expval?
    (num-val
        (value number?))
    (bool-val
        (boolean boolean?))
    (proc-val
        (proc proc?)))

(define expval->num
    (lambda (v)
        (cases expval v
            (num-val (num) num)
            (else (expval-extractor-error 'num v)))))

(define expval->bool
    (lambda (v)
        (cases expval v
            (bool-val (bool) bool)
            (else (expval-extractor-error 'bool v)))))

(define expval->proc
    (lambda (v)
        (cases expval v
            (proc-val (proc) proc)
            (else (expval-extractor-error 'proc v)))))

(define expval-extractor-error
    (lambda (variant value)
        (eopl:error 'expval-extractors "Looking for a ~s, found ~s" variant value)))



; eval

(define value-of-program 
    (lambda (pgm)
        (cases program pgm
            (a-program (exp1)
                (value-of exp1 (init-env))))))

(define value-of
    (lambda (exp env)
        (cases expression exp
            (const-exp (num) (num-val num))
            
            (var-exp (var) (apply-env env var))

            (diff-exp (exp1 exp2)
                (let ((val1 (value-of exp1 env))
                    (val2 (value-of exp2 env)))
                (let ((num1 (expval->num val1))
                        (num2 (expval->num val2)))
                    (num-val
                        (- num1 num2)))))

            (zero?-exp (exp1)
                (let ((val1 (value-of exp1 env)))
                    (let ((num1 (expval->num val1)))
                        (if (zero? num1)
                            (bool-val #t)
                            (bool-val #f)))))
                    
            (if-exp (exp1 exp2 exp3)
                (let ((val1 (value-of exp1 env)))
                    (if (expval->bool val1)
                        (value-of exp2 env)
                        (value-of exp3 env))))

            (let-exp (var exp1 body)       
                (let ((val1 (value-of exp1 env)))
                    (value-of body
                        (extend-env var val1 env))))
            
            (proc-exp (var body)
                (proc-val (procedure var body env)))
            
            (call-exp (rator rand)
                (let ((proc (expval->proc (value-of rator env)))
                    (arg (value-of rand env)))
                (apply-procedure proc arg)))
                
            )))

; exec

(define init-env
    (lambda ()
        (extend-env 
            'i (num-val 1)
            (extend-env
                'v (num-val 5)
                (extend-env
                    'x (num-val 10)
                    (empty-env))))))

(define run
    (lambda (string)
        (value-of-program (scan&parse string))))

(define input (read))
(display (run input))
(display "\n")