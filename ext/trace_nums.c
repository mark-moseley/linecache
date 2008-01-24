#include <ruby.h>
#include <version.h>
#include <node.h>
#include <env.h>
#include <rubysig.h>
#include "trace_nums.h"

VALUE mTraceLineNumbers;
extern NODE *ruby_eval_tree_begin;

#define nd_3rd   u3.node
static unsigned case_level = 0;
static unsigned when_level = 0;
static unsigned inside_case_args = 0;

struct METHOD {
  VALUE klass, rklass;
  VALUE recv;
  ID id, oid;
#if RUBY_VERSION_CODE > 182
  int safe_level;
#endif
  NODE *body;
};

struct BLOCK {
  NODE *var;
  NODE *body;
  VALUE self;
  struct FRAME frame;
  struct SCOPE *scope;
  VALUE klass;
  NODE *cref;
  int iter;
  int vmode;
  int flags;
  int uniq;
  struct RVarmap *dyna_vars;
  VALUE orig_thread;
  VALUE wrapper;
  VALUE block_obj;
  struct BLOCK *outer;
  struct BLOCK *prev;
};

#define RETURN					\
  goto finish

#define ADD_EVENT_LINE(node)			\
  rb_ary_push(ary, INT2NUM(nd_line(node)))

#define ADD_EVENT_CALL(node)			\
  rb_ary_push(ary, INT2NUM(nd_line(node)))


/* Used just in debugging. */
static indent_level = 0;

static
void add_line_numbers(VALUE self, NODE * n, VALUE ary) {
  NODE * volatile contnode = 0;
  NODE * volatile node = n;
  VALUE current;

  if (RTEST(ruby_debug)) {
    char fmt[30] = { '\0', };
    snprintf(fmt, sizeof(fmt), "%%%ds", indent_level+1);
    fprintf(stderr, fmt, "[");
    indent_level += 2;
  }

again:
  if (!node) RETURN;

  if (RTEST(ruby_debug)) {
    fprintf(stderr, "%s ", NODE2NAME[nd_type(node)]);
  }

  switch (nd_type(node)) {
  case NODE_BLOCK:
    if (contnode) {
      ADD_EVENT_LINE(node);
      contnode = 0;
      goto again;
    }
    contnode = node->nd_next;
    node = node->nd_head;
    goto again;

  case NODE_POSTEXE: /* END { ... } */
    /* Nothing to do here... we are in an iter block */
    break;

    /* begin .. end without clauses */
  case NODE_BEGIN:
    /* node for speed-up(top-level loop for -n/-p) */
  case NODE_OPT_N:
  case NODE_NOT:
    node = node->nd_body;
    goto again;

    /* nodes for speed-up(default match) */
  case NODE_MATCH:
    break;

    /* nodes for speed-up(literal match) */
  case NODE_MATCH2:
    add_line_numbers(self, node->nd_recv, ary); /* r */
    node = node->nd_value; /* l */
    goto again;

  case NODE_MATCH3:
    add_line_numbers(self, node->nd_recv, ary);  /* r */
    /* It is possible that l can be a function call which
       can trigger an call event. So to be conservative, 
       we have to add a line number here. */
    ADD_EVENT_CALL(node);
    node = node->nd_value; /* l */
    goto again;

  case NODE_SELF:
  case NODE_NIL:
  case NODE_TRUE:
  case NODE_FALSE:
    RETURN;

  case NODE_IF:
    ADD_EVENT_LINE(node);
    add_line_numbers(self, node->nd_cond, ary);
    if (node->nd_body) {
      if (!node->nd_else) {
	node = node->nd_body;
	goto again;
      }
      add_line_numbers(self, node->nd_body, ary);
    }
    if (node->nd_else) {
      node = node->nd_else;
      goto again;
    }
    break;

  case NODE_WHEN:
    while (node) {
      NODE *tag = node->nd_head;
      if (nd_type(node) != NODE_WHEN) goto again;
      while (tag) {
	ADD_EVENT_LINE(tag);
	if (tag->nd_head && nd_type(tag->nd_head) == NODE_WHEN) {
	  add_line_numbers(self, tag->nd_head->nd_head, ary); /* args */
	  tag = tag->nd_next;
	  continue;
	}
	add_line_numbers(self, tag->nd_head, ary); /* args */
	add_line_numbers(self, tag->nd_body, ary);
	tag = tag->nd_next;
      }
      node = node->nd_next;
    }
    RETURN;

  case NODE_CASE:
    {
      add_line_numbers(self, node->nd_head, ary);
      node = node->nd_body;
      while (node) {
	NODE *tag;
	if (nd_type(node) != NODE_WHEN) {
	  goto again;
	}
	tag = node->nd_head;
	while (tag) {
	  ADD_EVENT_LINE(tag);
	  if (tag->nd_head && nd_type(tag->nd_head) == NODE_WHEN) {
	    add_line_numbers(self, tag->nd_head->nd_head, ary); /* args */
	    tag = tag->nd_next;
	  }
	  add_line_numbers(self, tag->nd_head, ary);
	  tag = tag->nd_next;
	}
	add_line_numbers(self, node, ary);
	node = node->nd_next;
      }
    }
    RETURN;

  case NODE_WHILE:
  case NODE_UNTIL:
    add_line_numbers(self, node->nd_cond, ary);
    if (node->nd_body) {
      node = node->nd_body;
      goto again;
    }
    break;

  case NODE_BLOCK_PASS:
    add_line_numbers(self, node->nd_body, ary);
    node = node->nd_iter;
    goto again;

  case NODE_ITER:
  case NODE_FOR:
    add_line_numbers(self, node->nd_iter, ary);
    if (node->nd_var != (NODE *)1
        && node->nd_var != (NODE *)2
        && node->nd_var != NULL) {
      add_line_numbers(self, node->nd_var, ary);
    } 
    node = node->nd_body;
    goto again;

#ifdef FINISHED
  case NODE_BREAK:
  case NODE_NEXT:
  case NODE_YIELD:
    if (node->nd_stts)
      add_line_numbers(self, current, node->nd_stts);
    break;

  case NODE_RESCUE:
      add_line_numbers(self, current, node->nd_1st);
      add_line_numbers(self, current, node->nd_2nd);
      add_line_numbers(self, current, node->nd_3rd);
    break;

  /*
  // rescue body:
  // begin stmt rescue exception => var; stmt; [rescue e2 => v2; s2;]* end
  // stmt rescue stmt
  // a = b rescue c
  */

  case NODE_RESBODY:
      if (node->nd_3rd) {
        add_line_numbers(self, current, node->nd_3rd);
      } else {
        rb_ary_push(current, Qnil);
      }
      add_line_numbers(self, current, node->nd_2nd);
      add_line_numbers(self, current, node->nd_1st);
    break;

  case NODE_ENSURE:
    add_line_numbers(self, current, node->nd_head);
    if (node->nd_ensr) {
      add_line_numbers(self, current, node->nd_ensr);
    }
    break;

  case NODE_AND:
  case NODE_OR:
    add_line_numbers(self, current, node->nd_1st);
    add_line_numbers(self, current, node->nd_2nd);
    break;

  case NODE_DOT2:
  case NODE_DOT3:
  case NODE_FLIP2:
  case NODE_FLIP3:
    add_line_numbers(self, current, node->nd_beg);
    add_line_numbers(self, current, node->nd_end);
    break;

  case NODE_RETURN:
    if (node->nd_stts)
      add_line_numbers(self, current, node->nd_stts);
    break;

  case NODE_ARGSCAT:
  case NODE_ARGSPUSH:
    add_line_numbers(self, current, node->nd_head);
    add_line_numbers(self, current, node->nd_body);
    break;

  case NODE_CALL:
  case NODE_FCALL:
  case NODE_VCALL:
    if (nd_type(node) != NODE_FCALL)
      add_line_numbers(self, current, node->nd_recv);
    rb_ary_push(current, ID2SYM(node->nd_mid));
    if (node->nd_args || nd_type(node) != NODE_FCALL)
      add_line_numbers(self, current, node->nd_args);
    break;

  case NODE_SUPER:
    add_line_numbers(self, current, node->nd_args);
    break;

  case NODE_BMETHOD:
    {
      struct BLOCK *data;
      Data_Get_Struct(node->nd_cval, struct BLOCK, data);
      if (data->var == 0 || data->var == (NODE *)1 || data->var == (NODE *)2) {
        rb_ary_push(current, Qnil);
      } else {
        add_line_numbers(self, current, data->var);
      }
      add_line_numbers(self, current, data->body);
      break;
    }
    break;

#if RUBY_VERSION_CODE < 190
  case NODE_DMETHOD:
    {
      struct METHOD *data;
      Data_Get_Struct(node->nd_cval, struct METHOD, data);
      rb_ary_push(current, ID2SYM(data->id));
      add_line_numbers(self, current, data->body);
      break;
    }
#endif

  case NODE_METHOD:
    add_line_numbers(self, current, node->nd_3rd);
    break;

  case NODE_SCOPE:
    add_line_numbers(self, current, node->nd_next);
    break;

  case NODE_OP_ASGN1:
    add_line_numbers(self, current, node->nd_recv);
#if RUBY_VERSION_CODE < 185
    add_line_numbers(self, current, node->nd_args->nd_next);
    rb_ary_pop(rb_ary_entry(current, -1)); /* no idea why I need this */
#else
    add_line_numbers(self, current, node->nd_args->nd_2nd);
#endif
    switch (node->nd_mid) {
    case 0:
      rb_ary_push(current, ID2SYM(rb_intern("||")));
      break;
    case 1:
      rb_ary_push(current, ID2SYM(rb_intern("&&")));
      break;
    default:
      rb_ary_push(current, ID2SYM(node->nd_mid));
      break;
    }
    add_line_numbers(self, current, node->nd_args->nd_head);
    break;

  case NODE_OP_ASGN2:
    add_line_numbers(self, current, node->nd_recv);
    rb_ary_push(current, ID2SYM(node->nd_next->nd_aid));

    switch (node->nd_next->nd_mid) {
    case 0:
      rb_ary_push(current, ID2SYM(rb_intern("||")));
      break;
    case 1:
      rb_ary_push(current, ID2SYM(rb_intern("&&")));
      break;
    default:
      rb_ary_push(current, ID2SYM(node->nd_next->nd_mid));
      break;
    }

    add_line_numbers(self, current, node->nd_value);
    break;

  case NODE_OP_ASGN_AND:
  case NODE_OP_ASGN_OR:
    add_line_numbers(self, current, node->nd_head);
    add_line_numbers(self, current, node->nd_value);
    break;

  case NODE_MASGN:
    add_line_numbers(self, current, node->nd_head);
    if (node->nd_args) {
      if (node->nd_args != (NODE *)-1) {
        add_line_numbers(self, current, node->nd_args);
      } else {
        rb_ary_push(current, wrap_into_node("splat", 0));
      }
    }
    add_line_numbers(self, current, node->nd_value);
    break;

  case NODE_LASGN:
  case NODE_IASGN:
  case NODE_DASGN:
  case NODE_DASGN_CURR:
  case NODE_CDECL:
  case NODE_CVASGN:
  case NODE_CVDECL:
  case NODE_GASGN:
    rb_ary_push(current, ID2SYM(node->nd_vid));
    add_line_numbers(self, current, node->nd_value);
    break;

  case NODE_VALIAS:           /* u1 u2 (alias $global $global2) */
#if RUBY_VERSION_CODE < 185
    rb_ary_push(current, ID2SYM(node->u2.id));
    rb_ary_push(current, ID2SYM(node->u1.id));
#else
    rb_ary_push(current, ID2SYM(node->u1.id));
    rb_ary_push(current, ID2SYM(node->u2.id));
#endif
    break;
  case NODE_ALIAS:            /* u1 u2 (alias :blah :blah2) */
#if RUBY_VERSION_CODE < 185
    rb_ary_push(current, wrap_into_node("lit", ID2SYM(node->u2.id)));
    rb_ary_push(current, wrap_into_node("lit", ID2SYM(node->u1.id)));
#else
    add_line_numbers(self, current, node->nd_1st);
    add_line_numbers(self, current, node->nd_2nd);
#endif
    break;

  case NODE_UNDEF:            /* u2    (undef name, ...) */
#if RUBY_VERSION_CODE < 185
    rb_ary_push(current, wrap_into_node("lit", ID2SYM(node->u2.id)));
#else
    add_line_numbers(self, current, node->nd_value);
#endif
    break;

  case NODE_COLON3:           /* u2    (::OUTER_CONST) */
    rb_ary_push(current, ID2SYM(node->u2.id));
    break;

  case NODE_HASH:
    {
      NODE *list;

      list = node->nd_head;
      while (list) {
        add_line_numbers(self, current, list->nd_head);
        list = list->nd_next;
        if (list == 0)
          rb_bug("odd number list for Hash");
        add_line_numbers(self, current, list->nd_head);
        list = list->nd_next;
      }
    }
    break;

  case NODE_ARRAY:
      while (node) {
        add_line_numbers(self, current, node->nd_head);
        node = node->nd_next;
      }
    break;

  case NODE_DSTR:
  case NODE_DSYM:
  case NODE_DXSTR:
  case NODE_DREGX:
  case NODE_DREGX_ONCE:
    {
      NODE *list = node->nd_next;
      rb_ary_push(current, rb_str_new3(node->nd_lit));
      while (list) {
        if (list->nd_head) {
          switch (nd_type(list->nd_head)) {
          case NODE_STR:
            add_line_numbers(self, current, list->nd_head);
            break;
          case NODE_EVSTR:
            add_line_numbers(self, current, list->nd_head);
            break;
          default:
            add_line_numbers(self, current, list->nd_head);
            break;
          }
        }
        list = list->nd_next;
      }
      switch (nd_type(node)) {
      case NODE_DREGX:
      case NODE_DREGX_ONCE:
        if (node->nd_cflag) {
          rb_ary_push(current, INT2FIX(node->nd_cflag));
        }
      }
    }
    break;

  case NODE_DEFN:
  case NODE_DEFS:
    if (node->nd_defn) {
      if (nd_type(node) == NODE_DEFS)
        add_line_numbers(self, current, node->nd_recv);
      rb_ary_push(current, ID2SYM(node->nd_mid));
      add_line_numbers(self, current, node->nd_defn);
    }
    break;

  case NODE_CLASS:
  case NODE_MODULE:
    rb_ary_push(current, ID2SYM((ID)node->nd_cpath->nd_mid));
    if (nd_type(node) == NODE_CLASS) {
      if (node->nd_super) {
        add_line_numbers(self, current, node->nd_super);
      } else {
        rb_ary_push(current, Qnil);
      }
    }
    add_line_numbers(self, current, node->nd_body);
    break;

  case NODE_SCLASS:
    add_line_numbers(self, current, node->nd_recv);
    add_line_numbers(self, current, node->nd_body);
    break;

  case NODE_ARGS: {
    if (node->nd_opt) {
      add_line_numbers(self, current, node->nd_opt);
    }
  }  break;

  case NODE_LVAR:
  case NODE_DVAR:
  case NODE_IVAR:
  case NODE_CVAR:
  case NODE_GVAR:
  case NODE_CONST:
  case NODE_ATTRSET:
    rb_ary_push(current, ID2SYM(node->nd_vid));
    break;

#endif
  case NODE_XSTR:             /* u1    (%x{ls}) */
    /* Issues rb_funcall(self, '`'...). So I think we have to 
     register a call event. */
    ADD_EVENT_CALL(node);
    break;
    
  case NODE_LIT:
    break;

  case NODE_NEWLINE:
    ADD_EVENT_LINE(node);
    node = node->nd_next;
    goto again;

#ifdef FINISHED
  case NODE_NTH_REF:          /* u2 u3 ($1) - u3 is local_cnt('~') ignorable? */
    rb_ary_push(current, INT2FIX(node->nd_nth));
    break;

  case NODE_BACK_REF:         /* u2 u3 ($& etc) */
    {
    char c = node->nd_nth;
    rb_ary_push(current, rb_str_intern(rb_str_new(&c, 1)));
    }
    break;

  case NODE_BLOCK_ARG:        /* u1 u3 (def x(&b) */
    rb_ary_push(current, ID2SYM(node->u1.id));
    break;

  case NODE_COLON2:
    add_line_numbers(self, current, node->nd_head);
    rb_ary_push(current, ID2SYM(node->nd_mid));
    break;

  /* these nodes are empty and do not require extra work: */
  case NODE_RETRY:
  case NODE_FALSE:
  case NODE_NIL:
  case NODE_SELF:
  case NODE_TRUE:
  case NODE_ZARRAY:
  case NODE_ZSUPER:
  case NODE_REDO:
    break;

  case NODE_SPLAT:
  case NODE_TO_ARY:
  case NODE_SVALUE:             /* a = b, c */
    add_line_numbers(self, current, node->nd_head);
    break;

  case NODE_ATTRASGN:           /* literal.meth = y u1 u2 u3 */
    /* node id node */
    if (node->nd_1st == RNODE(1)) {
      add_line_numbers(self, current, NEW_SELF());
    } else {
      add_line_numbers(self, current, node->nd_1st);
    }
    rb_ary_push(current, ID2SYM(node->u2.id));
    add_line_numbers(self, current, node->nd_3rd);
    break;

  case NODE_STR:              /* u1 */
    rb_ary_push(current, node->nd_lit);
    if (node->nd_cflag) {
      rb_ary_push(current, INT2FIX(node->nd_cflag));
    }
    break;

  case NODE_EVSTR:
    add_line_numbers(self, current, node->nd_2nd);
    break;

  case NODE_CFUNC:
  case NODE_IFUNC:
    rb_ary_push(current, INT2NUM((long)node->nd_cfnc));
    rb_ary_push(current, INT2NUM(node->nd_argc));
    break;

#if RUBY_VERSION_CODE >= 190
  case NODE_ERRINFO:
  case NODE_VALUES:
  case NODE_PRELUDE:
  case NODE_LAMBDA:
    rb_warn("no worky in 1.9 yet");
    break;
#endif

  /* Nodes we found but have yet to decypher */
  /* I think these are all runtime only... not positive but... */
  case NODE_MEMO:               /* enum.c zip */
  case NODE_CREF:
  /* #defines: */
  /* case NODE_LMASK: */
  /* case NODE_LSHIFT: */
#endif /* FINISHED */
  default:
    rb_warn("Unhandled node %s", NODE2NAME[nd_type(node)]);
    if (RNODE(node)->u1.node != NULL) rb_warning("unhandled u1 value");
    if (RNODE(node)->u2.node != NULL) rb_warning("unhandled u2 value");
    if (RNODE(node)->u3.node != NULL) rb_warning("unhandled u3 value");
    if (RTEST(ruby_debug)) fprintf(stderr, "u1 = %p u2 = %p u3 = %p\\n", (void*)node->nd_1st, (void*)node->nd_2nd, (void*)node->nd_3rd);
    break;
  }
  finish:
    if (contnode) {
	node = contnode;
	contnode = 0;
	goto again;
    }
    if (RTEST(ruby_debug)) {
      char fmt[30] = { '\0', };
      indent_level -= 2;
      snprintf(fmt, sizeof(fmt), "%%%ds", indent_level+1);
      fprintf(stderr, fmt, "]\n");
    }

} /* add_line_numbers block */

/* Return a list of trace hook line numbers for the string in Ruby source src*/
static VALUE 
lnums_for_str(VALUE self, VALUE src) {
  VALUE result = rb_ary_new(); /* The returned array of line numbers. */
  NODE *node = NULL;
  int critical;

  ruby_nerrs = 0;
  StringValue(src); /* Check that src is a string. */

  critical = rb_thread_critical;
  rb_thread_critical = Qtrue;

  /* Making ruby_in_eval nonzero signals rb_compile_string not to save
     source in SCRIPT_LINES__. */
  ruby_in_eval++; 
  node = rb_compile_string("(numbers_for_str)", src, 1);
  ruby_in_eval--;

  rb_thread_critical = critical;

  if (ruby_nerrs > 0) {
    ruby_nerrs = 0;
#if RUBY_VERSION_CODE < 190
    ruby_eval_tree_begin = 0;
#endif
    rb_exc_raise(ruby_errinfo);
  }

  if (RTEST(ruby_debug)) {
    indent_level = 0;
  }
  add_line_numbers(self, node, result);
  return result;
}

void Init_trace_nums(void)
{
    mTraceLineNumbers = rb_define_module("TraceLineNumbers");
    rb_define_module_function(mTraceLineNumbers, "lnums_for_str", lnums_for_str, 1);
}
