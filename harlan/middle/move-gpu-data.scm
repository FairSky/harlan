(library
 (harlan middle move-gpu-data)
 (export move-gpu-data verify-move-gpu-data)
 (import
  (rnrs)
  (util verify-grammar)
  (util match)
  (util helpers))

 (generate-verify move-gpu-data
   (Module wildcard))

 (define-match move-gpu-data
   ((module ,[Decl -> decl*] ...)
    `(module . ,decl*)))

 (define-match Decl
   ((gpu-module ,kernel* ...)
    `(gpu-module . ,kernel*))
   ((extern ,name ,args -> ,type)
    `(extern ,name ,args -> ,type))
   ((fn ,name ,args ,type ,[Stmt -> stmt*] ...)
    `(fn ,name ,args ,type . ,(apply append stmt*))))

 (define-match Stmt
   ((do ,[Expr -> e*] ...)
    `((do . ,e*)))
   ((let ,x ,t ,[Expr -> expr])
    (guard (ident? x))
    `((let ,x ,t ,expr)))
   ((for (,x ,[Expr -> start] ,[Expr -> end]) ,[stmt*] ...)
    (guard (ident? x))
    `((for (,x ,start ,end) . ,(apply append stmt*))))
   ((while ,[Expr -> test] ,[stmt*] ...)
    `((while ,test . ,(apply append stmt*))))
   ((set! ,[Expr -> x] ,[Expr -> v])
    `((set! ,x ,v)))
   ((apply-kernel ,k ,[Expr -> expr*] ...)
    (guard (ident? k))
    (let-values (((prologue args epilogue)
                  (make-gpu-decls expr*)))
      `(,@prologue
        (apply-kernel ,k ,@args)
        ,@epilogue)))
   ((print ,[Expr -> expr])
    `((print ,expr)))
   ((assert ,[Expr -> expr])
    `((assert ,expr)))
   ((return ,[Expr -> expr])
    `((return ,expr))))

 (define (make-gpu-decls expr*)
   (if (null? expr*)
       (values '() '() '())
       (let-values (((prologue* arg* epilogue*)
                     (make-gpu-decls (cdr expr*)))
                    ((prologue arg epilogue)
                     (make-gpu-decl (car expr*))))
         (values
          (append prologue prologue*)
          (cons arg arg*)
          (append epilogue epilogue*)))))

 (define (make-gpu-decl expr)
   (match expr
     ((var ,t ,x)
      (guard (ident? x))
      (match t
        ((vector ,t^ ,n)
         (let ((gpu-var (gensym 'gpu))
               (gpu-ptr (gensym 'ptr)))
           (values
            `((let-gpu ,gpu-var ,t)
              (map-gpu ((,gpu-ptr (var ,t ,gpu-var)))
                       (set! (var ,t ,gpu-ptr) (var ,t ,x))))
            `(var ,t ,gpu-var)
            `((map-gpu ((,gpu-ptr (var ,t ,gpu-var)))
                       (set! (var ,t ,x) (var ,t ,gpu-ptr)))))))
        (,scalar
         (guard (symbol? scalar))
         (values '() expr '()))))
     (,else (error 'make-gpu-decl "Unsupported GPU arg" else))))
 
 (define-match Expr
   ((int ,n) (guard (integer? n))
    `(int ,n))
   ((float ,f) `(float ,f))
   ((var ,t ,x) (guard (ident? x))
    `(var ,t ,x))
   ((str ,s) (guard (string? s)) `(str ,s))
   ((cast ,t ,[e])
    `(cast ,t ,e))
   ((sizeof ,t) `(sizeof ,t))
   ((addressof ,[e]) `(addressof ,e))
   ((field ,[obj] ,x)
    (guard (ident? x))
    `(field ,obj ,x))
   ((call ,t ,f ,[e*] ...)
    (guard (ident? f))
    `(call ,t ,f . ,e*))
   ((call ,t ,[f] ,[e*] ...)
    `(call ,t ,f . ,e*))
   ((vector-ref ,t ,[v] ,[i])
    `(vector-ref ,t ,v ,i))
   ((,op ,[lhs] ,[rhs])
    (guard (or (binop? op) (relop? op)))
    `(,op ,lhs ,rhs)))
 
 ;; end library
 )