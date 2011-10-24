(library
  (harlan middle convert-types)
  (export convert-types)
  (import (only (chezscheme) format)
    (rnrs)
    (util helpers)
    (util match))
  
;; This pass converts Harlan types into C types.
(define-match convert-types
  ((,[convert-decl -> decl*] ...)
   decl*))

(define-match convert-decl
  ((gpu-module ,[convert-kernel -> kernel*] ...)
   `(gpu-module . ,kernel*))
  ((func ,[convert-type -> rtype] ,name ((,x* ,[convert-type -> t*]) ...)
     ,[convert-stmt -> stmt*] ...)
   (guard (andmap ident? x*))
   `(func ,rtype ,name ,(map list x* t*) . ,stmt*))
  ((extern ,[convert-type -> t] ,name (,[convert-type -> t*] ...))
   `(extern ,t ,name ,t*)))

(define-match convert-kernel
  ((kernel ,k ((,x* ,[convert-type -> t*]) ...) ,[convert-stmt -> stmt*] ...)
   (guard (ident? k))
   `(kernel ,k ,(map list x* t*) . ,stmt*)))

(define-match convert-stmt
  ((let ,x ,[convert-type -> type] ,[convert-expr -> e])
   (guard (symbol? x))
   `(let ,x ,type ,e))
  ((let-gpu ,x ,[convert-type -> type])
   (guard (ident? x))
   `(let-gpu ,x ,type))
  ((map-gpu ((,x* ,[convert-expr -> e*]) ...) ,[stmt*] ...)
   `(map-gpu ,(map list x* e*) . ,stmt*))
  ((set! ,[convert-expr -> loc] ,[convert-expr -> val])
   `(set! ,loc ,val))
  ((print ,[convert-expr -> e]) `(print ,e))
  ((while (,relop ,[convert-expr -> e1] ,[convert-expr -> e2])
     ,[convert-stmt -> stmt*] ...)
   (guard (relop? relop))
   `(while (,relop ,e1 ,e2) . ,stmt*))
  ((block ,[stmt*] ...)
   `(block . ,stmt*))
  ((for (,x ,[convert-expr -> begin] ,[convert-expr -> end])
     ,[convert-stmt -> stmt*] ...)
   (guard (symbol? x))
   `(for (,x ,begin ,end) . ,stmt*))
  ((kernel (((,x* ,[convert-type -> t*]) (,xs* ,[convert-type -> ts*])) ...)
     (free-vars (,fx* ,[convert-type -> ft*]) ...)
     ,[body*] ...)
   `(kernel ,(map (lambda (x t xs ts)
                    `((,x ,t) (,xs ,ts)))
               x* t* xs* ts*)
      (free-vars . ,(map list fx* ft*))
      . ,body*))
  ((apply-kernel ,k ,[convert-expr -> e*] ...)
   (guard (ident? k))
   `(apply-kernel ,k . ,e*))
  ((do ,[convert-expr -> e*] ...)
   `(do . ,e*))
  ((return ,[convert-expr -> expr])
   `(return ,expr)))

(define-match convert-expr
  (,n (guard (number? n)) n)
  (,s (guard (string? s)) s)
  (,x (guard (ident? x))  x)
  ((,op ,[lhs] ,[rhs]) (guard (binop? op))
   `(,op ,lhs ,rhs))
  ;; sizeof might need some more work, since (sizeof (vector int 4))
  ;; != (sizeof (ptr int))
  ((sizeof ,[convert-type -> t]) `(sizeof ,t))
  ((vector-ref ,[convert-expr -> v]
     ,[convert-expr -> i])
   `(vector-ref ,v ,i))
  ((cast ,[convert-type -> t] ,[e]) `(cast ,t ,e))
  ((deref ,[e]) `(deref ,e))
  ((addressof ,[e]) `(addressof ,e))
  ((assert ,[convert-expr -> expr]) `(assert ,expr))
  ((,[fn] ,[convert-expr -> arg*] ...)
   `(,fn . ,arg*)))

(define-match convert-type
  (int 'int)
  (u64 'uint64_t)
  (float 'float)
  (void 'void)
  (str '(ptr char))
  (cl::kernel 'cl::kernel)
  ((cl::buffer ,[t]) `(cl::buffer ,t))
  ((cl::buffer_map ,[t]) `(cl::buffer_map ,t))
  ((ptr ,scalar)
   (guard (scalar-type? scalar))
   `(ptr ,scalar))
  ((vector ,[find-leaf-type -> t] ,size)
   `(ptr ,(convert-type t)))
  (((,[t*] ...) -> ,[t])
   `(,t* -> ,t)))

(define-match find-leaf-type
  ((vector ,[t] ,size) t)
  (,t (guard (harlan-scalar-type? t)) t))

(define harlan-scalar-type?
  (lambda (t)
    (case t
      ((int) #t)
      (else #f))))

;; end library
)
